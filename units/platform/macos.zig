const std = @import("std");
const vk = @import("vulkan");
const Handle = @import("utils").Handle;
const InstanceDispatch = @import("../device/vulkan/dispatch_types.zig").InstanceDispatch;
const Event = @import("events.zig").Event;
const Window = @import("window.zig");
const FreeList = @import("../containers/freelist.zig").FreeList;

extern fn startup(state: *macos_state) bool;
extern fn shutdown(state: *macos_state) void;
extern fn create_window(title: [*:0]const u8, w: i32, h: i32, wd: *WinData) bool;
pub extern fn pump_messages(state: *macos_state) bool;

const macos_state = extern struct {
    app_delegate: *anyopaque,
    wnd_delegate: *anyopaque,
};

var state: macos_state = undefined;

var num_living: usize = 0;
var windows: FreeList(WinData) = undefined;
var window_store: [10]WinData = undefined;

pub fn init() anyerror!void {
    utils.log.info("macos startup", .{});
    _ = startup(&state);
    windows = try FreeList(WinData).initArena(&window_store);
}

pub fn deinit() void {
    utils.log.info("macos shutdown", .{});
    shutdown(&state);
}

var next_event: ?Event = null;

pub fn nextEvent() ?Event {
    next_event = null;
    while (pump_messages(&state)) {
        if (num_living == 0) {
            return Event{ .Quit = .{} };
        }

        if (next_event) |ne| {
            return ne;
        }
    }
    return null;
}

export fn mouse_move(x: i16, y: i16) void {
    _ = x;
    _ = y;
}

pub const WinData = struct {
    window: *anyopaque,
    view: *anyopaque,
    layer: *vk.CAMetalLayer,
};

export fn find_win(window: *anyopaque) ?*WinData {
    var iter = windows.iter();
    while (iter.next()) |wd| {
        if (@ptrToInt(wd.window) == @ptrToInt(window)) {
            return wd;
        }
    }
    return null;
}

pub fn createWindow(title: []const u8, w: u32, h: u32) !Window {
    const id: u32 = try windows.allocIndex();
    var wd = &window_store[id];

    if (!create_window(@ptrCast([*:0]const u8, title.ptr), @intCast(i32, w), @intCast(i32, h), wd)) {
        return error.FailedWindow;
    }

    num_living += 1;

    return Window{
        .handle = @intToEnum(Handle(.Window), id),
    };
}

export fn close_window(ptr: *anyopaque) void {
    const id: u32 = @truncate(u32, @ptrToInt(ptr));
    utils.log.info("closing {x}", .{id});
    num_living -= 1;
}

export fn resize_window(ptr: *anyopaque, w: u16, h: u16) void {
    const wd = find_win(ptr).?;
    next_event = Event{ .WindowResize = .{ .w = w, .h = h } };
    _ = wd;
    //utils.log.info("win: {} resized to {}x{}", .{ wd, w, h });
}

pub fn createWindowSurface(vki: InstanceDispatch, instance: vk.Instance, win: Window) !vk.SurfaceKHR {
    const idx = @enumToInt(win.handle);
    return vki.createMetalSurfaceEXT(instance, &.{
        .flags = .{},
        .p_layer = window_store[idx].layer,
    }, null);
}
