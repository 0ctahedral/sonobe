const std = @import("std");
const Handle = @import("utils").Handle;
const FreeList = @import("containers").FreeList;
const log = @import("utils").log.default;
const Event = @import("events.zig");

extern fn startup(state: *macos_state) bool;
extern fn shutdown(state: *macos_state) void;
extern fn create_window(title: [*:0]const u8, w: i32, h: i32, wd: *WinData) bool;
pub extern fn pump_messages(state: *macos_state) bool;

const macos_state = extern struct {
    app_delegate: *anyopaque,
    wnd_delegate: *anyopaque,
};

pub const WinData = extern struct {
    window: *anyopaque,
    view: *anyopaque,
    // layer: *vk.CAMetalLayer,
    layer: *anyopaque,
};

var state: macos_state = undefined;

var num_living: usize = 0;
var windows: FreeList(WinData) = undefined;
var window_store: [10]WinData = undefined;

pub const PlatformSettings = struct {};

pub fn init(settings: PlatformSettings) anyerror!void {
    _ = settings;
    log.info("macos startup", .{});
    _ = startup(&state);
    windows = try FreeList(WinData).initArena(&window_store);
}

pub fn deinit() void {
    log.info("macos shutdown", .{});
    shutdown(&state);
}

pub fn createWindow(title: []const u8, w: u32, h: u32) !void {
    const id: u32 = try windows.allocIndex();
    var wd = &window_store[id];

    if (!create_window(@ptrCast([*:0]const u8, title.ptr), @intCast(i32, w), @intCast(i32, h), wd)) {
        return error.FailedWindow;
    }

    num_living += 1;

    // return Window{
    //     .handle = @intToEnum(Handle(.Window), id),
    // };
}

pub fn poll() void {
    while (pump_messages(&state)) {}
}

// functions we export as callbacks for cocoa

export fn mouse_move(x: i16, y: i16) void {
    _ = x;
    _ = y;
}

export fn win_ptr_to_data(window: *anyopaque) ?*WinData {
    var iter = windows.iter();
    while (iter.next()) |wd| {
        if (@ptrToInt(wd.window) == @ptrToInt(window)) {
            return wd;
        }
    }
    return null;
}

export fn close_window(ptr: *anyopaque) void {
    const id: u32 = @truncate(u32, @ptrToInt(ptr));
    log.info("closing {x}", .{id});
    num_living -= 1;
}

export fn resize_window(ptr: *anyopaque, w: u16, h: u16) void {
    const wd = win_ptr_to_data(ptr).?;
    // next_event = Event{ .WindowResize = .{ .w = w, .h = h } };
    log.info("win: {} resized to {}x{}", .{ wd, w, h });
}
