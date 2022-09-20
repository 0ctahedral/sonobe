const std = @import("std");
const os = std.os;
const xcb = @import("xcb_decls.zig").XCB;
const Window = @import("window.zig");
const vk = @import("vulkan");
const Handle = @import("utils").Handle;
const InstanceDispatch = @import("../device/vulkan/dispatch_types.zig").InstanceDispatch;
const Event = @import("events.zig").Event;

var display: *xcb.Display = undefined;
var connection: *xcb.xcb_connection_t = undefined;
var screen: *xcb.xcb_screen_t = undefined;

var windows: struct {
    /// idx of the next open spot
    idx: usize = 0,
    // number of windows still living
    num_living: usize = 0,
    handles: [32]xcb.xcb_window_t = undefined,
    wm_dels: [32]xcb.xcb_atom_t = undefined,
    wm_protos: [32]xcb.xcb_atom_t = undefined,
} = .{};

pub fn init() anyerror!void {
    utils.log.info("linux startup", .{});

    display = xcb.XOpenDisplay(null).?;
    //_ = xcb.XAutoRepeatOff(display);
    connection = xcb.XGetXCBConnection(display);
    if (xcb.xcb_connection_has_error(connection) != 0) {
        return error.XcbConnectionFail;
    }
    var itr: xcb.xcb_screen_iterator_t = xcb.xcb_setup_roots_iterator(xcb.xcb_get_setup(connection));
    // Use the last screen
    screen = @ptrCast(*xcb.xcb_screen_t, itr.data);
}

pub fn deinit() void {
    //_ = xcb.XAutoRepeatOn(display);
    utils.log.info("linux shutdown", .{});
}

pub fn nextEvent() ?Event {
    var ret: ?Event = null;

    if (xcb.xcb_poll_for_event(connection)) |ev| {
        _ = ev;
        // Input events
        switch (ev.*.response_type & ~@as(u32, 0x80)) {
            //            xcb.XCB_KEY_PRESS,
            //            xcb.XCB_KEY_RELEASE => {
            //                const kev = @ptrCast(*xcb_key_press_event_t, ev);
            //                const pressed = kev.response_type == XCB_KEY_PRESS;
            //
            //                const code = kev.detail;
            //                const key_sym = XkbKeycodeToKeysym(
            //                    display,
            //                    code,  //event.xkey.keycode,
            //                    0,
            //                    if (code & ShiftMask == 1) 1 else 0);
            //
            //                const key = translateKey(key_sym);
            //                try input.processKey(key, pressed);
            //
            //            },
            xcb.XCB_CLIENT_MESSAGE => {
                const cm = @ptrCast(*xcb.xcb_client_message_event_t, ev);
                utils.log.info("wm window close event: {}", .{cm});
                for (windows.handles) |*handle, i| {
                    if (
                    //handle.* != .null_handle and
                    cm.window == handle.* and
                        cm.*.data.data32[0] == windows.wm_dels[i])
                    {
                        _ = xcb.xcb_destroy_window(connection, handle.*);
                        windows.num_living -= 1;
                        if (windows.num_living == 0) {
                            return Event{ .Quit = .{} };
                        }
                        return Event{ .WindowClose = @intToEnum(Handle(.Window), i) };
                    }
                }
            },
            //            xcb.XCB_BUTTON_PRESS,
            //            xcb.XCB_BUTTON_RELEASE => {
            //                const bev = @ptrCast(*xcb_key_press_event_t, ev);
            //                const pressed = bev.response_type == XCB_BUTTON_PRESS;
            //                var btn: input.mouse_btns = undefined;
            //                switch (bev.detail) {
            //                    1 => btn = input.mouse_btns.left,
            //                    2 => btn = input.mouse_btns.middle,
            //                    3 => btn = input.mouse_btns.right,
            //                    else => {
            //                        // TODO: use buttons 4 and 5 to add scrolling
            //                        utils.log.info("button press: {}", .{bev.detail});
            //                        btn = input.mouse_btns.other;
            //                    },
            //                }
            //                input.processMouseBtn(btn, pressed);
            //            },
            //            xcb.XCB_MOTION_NOTIFY => {
            //                const motion = @ptrCast(*xcb_motion_notify_event_t, ev);
            //                input.processMouseMove(motion.event_x, motion.event_y);
            //            },
            //            // for resizes
            xcb.XCB_CONFIGURE_NOTIFY => {
                const cn = @ptrCast(*xcb.xcb_configure_notify_event_t, ev);
                ret = Event{ .WindowResize = .{
                    .x = cn.x,
                    .y = cn.y,
                    .w = cn.width,
                    .h = cn.height,
                } };
            },
            //else => |ev| utils.log.info("event: {}", .{ev}),
            //else => utils.log.info("event: {}", .{ev}),
            else => {},
        }
        _ = xcb.xcb_flush(connection);
    }

    return ret;
}

pub fn createWindow(title: []const u8, w: u32, h: u32) !Window {
    // Allocate an id for our window
    const window = xcb.xcb_generate_id(connection);

    // We are setting the background pixel color and the event mask
    const mask: u32 = xcb.XCB_CW_BACK_PIXEL | xcb.XCB_CW_EVENT_MASK;

    // background color and events to request
    const values = [_]u32{ screen.*.black_pixel, xcb.XCB_EVENT_MASK_BUTTON_PRESS | xcb.XCB_EVENT_MASK_BUTTON_RELEASE |
        xcb.XCB_EVENT_MASK_KEY_PRESS | xcb.XCB_EVENT_MASK_KEY_RELEASE |
        xcb.XCB_EVENT_MASK_EXPOSURE | xcb.XCB_EVENT_MASK_POINTER_MOTION |
        xcb.XCB_EVENT_MASK_STRUCTURE_NOTIFY };

    // Create the window
    const cookie: xcb.xcb_void_cookie_t = xcb.xcb_create_window(connection, xcb.XCB_COPY_FROM_PARENT, window, screen.*.root, 0, 0, @intCast(u16, w), @intCast(u16, h), 0, xcb.XCB_WINDOW_CLASS_INPUT_OUTPUT, screen.*.root_visual, mask, values[0..]);

    _ = cookie;

    // Notify us when the window manager wants to delete the window
    const datomname = "WM_DELETE_WINDOW";
    const wm_delete_reply = xcb.xcb_intern_atom_reply(connection, xcb.xcb_intern_atom(connection, 0, datomname.len, datomname), null);
    const patomname = "WM_PROTOCOLS";
    const wm_protocols_reply = xcb.xcb_intern_atom_reply(connection, xcb.xcb_intern_atom(connection, 0, patomname.len, patomname), null);

    //// store the atoms
    var wm_del = wm_delete_reply.*.atom;
    var wm_proto = wm_protocols_reply.*.atom;

    // ask the sever to actually set the atom
    _ = xcb.xcb_change_property(connection, xcb.XCB_PROP_MODE_REPLACE, window, wm_proto, 4, 32, 1, &wm_del);

    // change the name

    _ = xcb.xcb_change_property(connection, xcb.XCB_PROP_MODE_REPLACE, window, xcb.XCB_ATOM_WM_NAME, xcb.XCB_ATOM_STRING, 8, // data should be viewed 8 bits at a time
        @intCast(u32, title.len), title.ptr);

    // Map the window to the screen
    _ = xcb.xcb_map_window(connection, window);

    if (xcb.xcb_flush(connection) <= 0) {
        return error.xcbFlushError;
    }

    utils.log.info("linux create window # {}", .{window});
    windows.idx += 1;
    windows.handles[windows.idx] = window;
    windows.wm_dels[windows.idx] = wm_del;
    windows.wm_protos[windows.idx] = wm_proto;
    windows.num_living += 1;

    return Window{
        .handle = Handle(.Window){ .id = windows.idx },
    };
}

pub fn createWindowSurface(vki: InstanceDispatch, instance: vk.Instance, win: Window) !vk.SurfaceKHR {
    var surf = vki.createXcbSurfaceKHR(instance, &.{
        .flags = .{},
        .connection = @ptrCast(*vk.xcb_connection_t, connection),
        .window = windows.handles[@enumToInt(win.handle)],
    }, null);
    return surf;
}
