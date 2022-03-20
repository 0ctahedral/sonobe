const std = @import("std");
const vk = @import("vulkan");
const InstanceDispatch = @import("../renderer/dispatch_types.zig").InstanceDispatch;
const Window = @import("window.zig");
const Event = @import("../events.zig").Event;

const macos_state = extern struct {
    app_delegate: *anyopaque,
    wnd_delegate: *anyopaque,
};

extern fn startup(state: *macos_state) bool;
extern fn shutdown(state: *macos_state) void;
extern fn create_window(title: [*:0]const u8, w: i32, h: i32, wd: *WinData) bool;
pub extern fn pump_messages(state: *macos_state) bool;

var state: macos_state = undefined;

var num_living: usize = 0;

pub fn init() anyerror!void {
    std.log.info("macos startup", .{});
    _ = startup(&state);
}

pub fn deinit() void {
    std.log.info("macos shutdown", .{});
    shutdown(&state);
}

pub fn nextEvent() ?Event {
    while (pump_messages(&state)) {
        if (num_living == 0) {
            return Event{ .Quit = .{} };
        }
    }
    return null;
}

export fn mouse_move(x: i16, y: i16) void {
    _ = x;
    _ = y;
    //std.log.debug("mouse at: {} {}", .{ x, y });
}

pub const WinData = struct {
    window: *anyopaque,
    view: *anyopaque,
    layer: *vk.CAMetalLayer,
};

var wd: WinData = undefined;

pub fn createWindow(title: [*:0]const u8, w: u32, h: u32) !Window {
    if (!create_window(title, @intCast(i32, w), @intCast(i32, h), &wd)) {
        return error.FailedWindow;
    }
    // TODO: is this dumb?
    const id: u32 = @truncate(u32, @ptrToInt(wd.window));
    std.log.debug("opening {x}", .{id});
    num_living += 1;
    return Window{
        .handle = @intToEnum(Window.Handle, id),
    };
}

export fn close_window(ptr: *anyopaque) void {
    const id: u32 = @truncate(u32, @ptrToInt(ptr));
    std.log.debug("closing {x}", .{id});
    num_living -= 1;
}

pub fn createWindowSurface(vki: InstanceDispatch, instance: vk.Instance, win: Window) !vk.SurfaceKHR {
    _ = win;
    return vki.createMetalSurfaceEXT(instance, &.{
        .flags = .{},
        .p_layer = wd.layer,
    }, null);
}
