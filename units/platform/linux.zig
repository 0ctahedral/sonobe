const std = @import("std");
const os = std.os;
const sys = os.linux;
const xcb = @import("xcb_decls.zig");
const Handle = @import("utils").Handle;
const events = @import("events.zig");
const input = @import("input.zig");
const Event = events.Event;
const log = @import("utils").log.default;
const PlatformSettings = @import("platform.zig").PlatformSettings;

var display: *xcb.Display = undefined;
var connection: *xcb.xcb_connection_t = undefined;
var screen: *xcb.xcb_screen_t = undefined;
var inotify: i32 = undefined;

var windows: struct {
    /// idx of the next open spot
    idx: u32 = 0,
    // number of windows still living
    num_living: usize = 0,
    handles: [32]xcb.xcb_window_t = undefined,
    wm_dels: [32]xcb.xcb_atom_t = undefined,
    wm_protos: [32]xcb.xcb_atom_t = undefined,
} = .{};

pub fn init(settings: PlatformSettings) anyerror!void {
    _ = settings;
    log.info("linux startup", .{});

    display = xcb.XOpenDisplay(null).?;
    //_ = xcb.XAutoRepeatOff(display);
    connection = xcb.XGetXCBConnection(display);
    if (xcb.xcb_connection_has_error(connection) != 0) {
        return error.XcbConnectionFail;
    }
    var itr: xcb.xcb_screen_iterator_t = xcb.xcb_setup_roots_iterator(xcb.xcb_get_setup(connection));
    // Use the last screen
    screen = @ptrCast(*xcb.xcb_screen_t, itr.data);

    // assume that we already have the joystick found
    const joystick_path: []const u8 = "/dev/input/by-id/usb-8BitDo_8BitDo_Pro_2_000000000003-event-joystick";
    const fd = try os.open(joystick_path, sys.O.RDONLY, undefined);
    _ = fd;
    log.info("opened device: {s}", .{joystick_path});
    // var bits: usize = 8;
    // _ = sys.ioctl(fd, 0, @ptrToInt(&num_axes));
    // log.info("bits: {}", .{bits});
}

pub fn deinit() void {
    //_ = xcb.XAutoRepeatOn(display);
    log.info("linux shutdown", .{});
}

pub fn poll() void {
    while (xcb.xcb_poll_for_event(connection)) |ev| {
        // Input events
        switch (ev.*.response_type & ~@as(u32, 0x80)) {
            xcb.XCB_KEY_PRESS => {
                const kev = @ptrCast(*xcb.xcb_key_press_event_t, ev);
                const code = kev.detail;
                const key_sym = xcb.XkbKeycodeToKeysym(
                    display,
                    code,
                    0,
                    if (code & xcb.ShiftMask == 1) 1 else 0,
                );

                const key = translateKey(key_sym);
                input.setModifier(Event{
                    .KeyPress = key,
                });
            },
            xcb.XCB_KEY_RELEASE => {
                const kev = @ptrCast(*xcb.xcb_key_press_event_t, ev);
                const code = kev.detail;
                const key_sym = xcb.XkbKeycodeToKeysym(
                    display,
                    code,
                    0,
                    if (code & xcb.ShiftMask == 1) 1 else 0,
                );

                const key = translateKey(key_sym);
                input.setModifier(Event{
                    .KeyRelease = key,
                });
            },
            xcb.XCB_CLIENT_MESSAGE => {
                const cm = @ptrCast(*xcb.xcb_client_message_event_t, ev);
                for (&windows.handles, 0..) |*handle, i| {
                    if (
                    //handle.* != .null_handle and
                    cm.window == handle.* and
                        cm.*.data.data32[0] == windows.wm_dels[i])
                    {
                        _ = xcb.xcb_destroy_window(connection, handle.*);
                        windows.num_living -= 1;
                        if (windows.num_living == 0) {
                            events.enqueue(Event{ .Quit = {} });
                        }
                        events.enqueue(Event{ .WindowClose = Handle(.Window){ .id = @intCast(u32, i) } });
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
            //                        log.info("button press: {}", .{bev.detail});
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
                events.enqueue(Event{ .WindowResize = .{
                    .x = cn.x,
                    .y = cn.y,
                    .w = cn.width,
                    .h = cn.height,
                } });
            },
            //else => |ev| log.info("event: {}", .{ev}),
            //else => log.info("event: {}", .{ev}),
            else => {},
        }
        _ = xcb.xcb_flush(connection);
    }
}

pub fn createWindow(title: []const u8, w: u32, h: u32) !Handle(.Window) {
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

    log.info("linux create window # {}", .{window});
    windows.idx += 1;
    windows.handles[windows.idx] = window;
    windows.wm_dels[windows.idx] = wm_del;
    windows.wm_protos[windows.idx] = wm_proto;
    windows.num_living += 1;

    return Handle(.Window){ .id = windows.idx };
}

/// TODO: does nothing for now
pub fn setWindowTitle(handle: Handle(.Window), title: []const u8) !void {
    _ = xcb.xcb_change_property(
        connection,
        xcb.XCB_PROP_MODE_REPLACE,
        windows.handles[handle.id],
        xcb.XCB_ATOM_WM_NAME,
        xcb.XCB_ATOM_STRING,
        8, // data should be viewed 8 bits at a time
        @intCast(u32, title.len),
        title.ptr,
    );
}

fn translateKey(key_sym: u32) input.Key {
    return switch (key_sym) {
        0x0020 => .space,
        0xff08 => .backspace,
        0xff09 => .tab,
        0xff0d => .enter,
        0xff13 => .pause,
        0xff14 => .scroll_lock,
        0xff1b => .escape,
        0xffff => .delete,

        0xffbe => .f1,
        0xffbf => .f2,
        0xffc0 => .f3,
        0xffc1 => .f4,
        0xffc2 => .f5,
        0xffc3 => .f6,
        0xffc4 => .f7,
        0xffc5 => .f8,
        0xffc6 => .f9,
        0xffc7 => .f10,
        0xffc8 => .f11,
        0xffc9 => .f12,
        0xffca => .f13,
        0xffcb => .f14,
        0xffcc => .f15,
        0xffcd => .f16,
        0xffce => .f17,
        0xffcf => .f18,
        0xffd0 => .f19,
        0xffd1 => .f20,
        0xffd2 => .f21,
        0xffd3 => .f22,
        0xffd4 => .f23,
        0xffd5 => .f24,
        0xffd6 => .f25,

        0xffe1 => .l_shift, // left shift */
        0xffe2 => .r_shift, // right shift */
        0xffe3 => .l_ctrl, // left control */
        0xffe4 => .l_ctrl, // right control */
        0xffe5 => .caps_lock, // caps lock */

        0xffe9 => .l_alt, // left alt */
        0xffea => .r_alt, // right alt */
        0xffeb => .l_super, // left super */
        0xffec => .r_super, // right super */

        0xff61 => .print,
        0xff63 => .insert, // insert, insert here */
        0xff67 => .menu,
        0xff7f => .num_lock,

        0xff50 => .home,
        0xff51 => .left, // move left, left arrow */
        0xff52 => .up, // move up, up arrow */
        0xff53 => .right, // move right, right arrow */
        0xff54 => .down, // move down, down arrow */
        0xff55 => .page_up,
        0xff56 => .page_down,
        0xff57 => .end, // eol */

        0x00d7 => .multiply,
        0xffbd => .equal,
        0xffab => .add,
        0xffac => .comma, // separator, often comma */
        0xffad => .subtract,
        0xffae => .decimal,
        0xffaf => .divide,

        0xffb0 => .kp_0,
        0xffb1 => .kp_1,
        0xffb2 => .kp_2,
        0xffb3 => .kp_3,
        0xffb4 => .kp_4,
        0xffb5 => .kp_5,
        0xffb6 => .kp_6,
        0xffb7 => .kp_7,
        0xffb8 => .kp_8,
        0xffb9 => .kp_9,

        0x0021 => .exclam, // u+0021 exclamation mark */
        0x0022 => .double_quote, // u+0022 quotation mark */
        0x0023 => .pound, // u+0023 number sign */
        0x0024 => .dollar, // u+0024 dollar sign */
        0x0025 => .percent, // u+0025 percent sign */
        0x0026 => .ampersand, // u+0026 ampersand */
        0x0027 => .apostrophe, // u+0027 apostrophe */
        0x0028 => .l_paren, // u+0028 left parenthesis */
        0x0029 => .r_paren, // u+0029 right parenthesis */
        0x002a => .asterisk, // u+002a asterisk */
        0x002b => .plus, // u+002b plus sign */
        0x002c => .comma, // u+002c comma */
        0x002d => .minus, // u+002d hyphen-minus */
        0x002e => .period, // u+002e full stop */
        0x002f => .slash, // u+002f solidus */
        0x0030 => .n0, // u+0030 digit zero */
        0x0031 => .n1, // u+0031 digit one */
        0x0032 => .n2, // u+0032 digit two */
        0x0033 => .n3, // u+0033 digit three */
        0x0034 => .n4, // u+0034 digit four */
        0x0035 => .n5, // u+0035 digit five */
        0x0036 => .n6, // u+0036 digit six */
        0x0037 => .n7, // u+0037 digit seven */
        0x0038 => .n8, // u+0038 digit eight */
        0x0039 => .n9, // u+0039 digit nine */
        0x003a => .colon, // u+003a colon */
        0x003b => .semicolon, // u+003b semicolon */
        0x003c => .less, // u+003c less-than sign */
        0x003d => .equal, // u+003d equals sign */
        0x003e => .greater, // u+003e greater-than sign */
        0x003f => .question, // u+003f question mark */
        0x0040 => .at, // u+0040 commercial at */
        0x005b => .l_bracket, // u+005b left square bracket */
        0x005c => .backslash, // u+005c reverse solidus */
        0x007b => .l_brace, // u+007b left curly bracket */
        0x007c => .bar, // u+007c vertical line */
        0x007d => .r_brace, // u+008d right curly bracket */
        0x005d => .r_bracket, // u+005d right square bracket */
        0x005f => .underscore, // u+005f low line */
        0x0060 => .grave, // u+0060 grave accent */
        0x0061 => .a, // u+0061 latin small letter a */
        0x0062 => .b, // u+0062 latin small letter b */
        0x0063 => .c, // u+0063 latin small letter c */
        0x0064 => .d, // u+0064 latin small letter d */
        0x0065 => .e, // u+0065 latin small letter e */
        0x0066 => .f, // u+0066 latin small letter f */
        0x0067 => .g, // u+0067 latin small letter g */
        0x0068 => .h, // u+0068 latin small letter h */
        0x0069 => .i, // u+0069 latin small letter i */
        0x006a => .j, // u+006a latin small letter j */
        0x006b => .k, // u+006b latin small letter k */
        0x006c => .l, // u+006c latin small letter l */
        0x006d => .m, // u+006d latin small letter m */
        0x006e => .n, // u+006e latin small letter n */
        0x006f => .o, // u+006f latin small letter o */
        0x0070 => .p, // u+0070 latin small letter p */
        0x0071 => .q, // u+0071 latin small letter q */
        0x0072 => .r, // u+0072 latin small letter r */
        0x0073 => .s, // u+0073 latin small letter s */
        0x0074 => .t, // u+0074 latin small letter t */
        0x0075 => .u, // u+0075 latin small letter u */
        0x0076 => .v, // u+0076 latin small letter v */
        0x0077 => .w, // u+0077 latin small letter w */
        0x0078 => .x, // u+0078 latin small letter x */
        0x0079 => .y, // u+0079 latin small letter y */
        0x007a => .z, // u+007a latin small letter z */
        0x0041 => .a, // u+0041 latin capital letter a */
        0x0042 => .b, // u+0042 latin capital letter b */
        0x0043 => .c, // u+0043 latin capital letter c */
        0x0044 => .d, // u+0044 latin capital letter d */
        0x0045 => .e, // u+0045 latin capital letter e */
        0x0046 => .f, // u+0046 latin capital letter f */
        0x0047 => .g, // u+0047 latin capital letter g */
        0x0048 => .h, // u+0048 latin capital letter h */
        0x0049 => .i, // u+0049 latin capital letter i */
        0x004a => .j, // u+004a latin capital letter j */
        0x004b => .k, // u+004b latin capital letter k */
        0x004c => .l, // u+004c latin capital letter l */
        0x004d => .m, // u+004d latin capital letter m */
        0x004e => .n, // u+004e latin capital letter n */
        0x004f => .o, // u+004f latin capital letter o */
        0x0050 => .p, // u+0050 latin capital letter p */
        0x0051 => .q, // u+0051 latin capital letter q */
        0x0052 => .r, // u+0052 latin capital letter r */
        0x0053 => .s, // u+0053 latin capital letter s */
        0x0054 => .t, // u+0054 latin capital letter t */
        0x0055 => .u, // u+0055 latin capital letter u */
        0x0056 => .v, // u+0056 latin capital letter v */
        0x0057 => .w, // u+0057 latin capital letter w */
        0x0058 => .x, // u+0058 latin capital letter x */
        0x0059 => .y, // u+0059 latin capital letter y */
        0x005a => .z, // u+005a latin capital letter z */
        0x007e => .tilde,
        0x0afc => .caret,

        else => .unknown,
    };
}
