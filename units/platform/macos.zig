const std = @import("std");
const Handle = @import("utils").Handle;
const FreeList = @import("containers").FreeList;
const Vec2 = @import("math").Vec2;
const log = @import("utils").log.default;
const events = @import("events.zig");
const Event = events.Event;
const PlatformSettings = @import("platform.zig").PlatformSettings;

extern fn startup(state: *macos_state) bool;
extern fn shutdown(state: *macos_state) void;
extern fn create_window(title: [*:0]const u8, w: i32, h: i32, wd: *WinData) bool;
extern fn get_window_size(wd: *WinData, w: *u16, h: *u16) void;
extern fn set_window_title(wd: *WinData, title: [*:0]const u8) void;
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

pub fn createWindow(title: []const u8, w: u32, h: u32) !Handle(.Window) {
    const id: u32 = try windows.allocIndex();
    var wd = &window_store[id];

    if (!create_window(@ptrCast([*:0]const u8, title.ptr), @intCast(i32, w), @intCast(i32, h), wd)) {
        return error.FailedWindow;
    }

    num_living += 1;

    return Handle(.Window){
        .id = id,
    };
}

/// does nothing for now
pub fn setWindowTitle(win: Handle(.Window), title: []const u8) !void {
    const win_ptr = &window_store[win.id];
    set_window_title(win_ptr, @ptrCast([*:0]const u8, title.ptr));
}

pub fn getWindowSize(win: Handle(.Window)) Vec2 {
    const win_ptr = &window_store[win.id];
    var w: u16 = 0;
    var h: u16 = 0;
    get_window_size(win_ptr, &w, &h);
    return .{
        .x = @intToFloat(f32, w),
        .y = @intToFloat(f32, h),
    };
}

pub fn poll() void {
    while (pump_messages(&state)) {}
}

// functions we export as callbacks for cocoa

export fn mouse_click(x: i16, y: i16) void {
    events.enqueue(Event{ .MouseButton = .{
        .button = .left,
        .action = .press,
        .pos = .{
            .x = @intToFloat(f32, x),
            .y = @intToFloat(f32, y),
        },
    } });
}

export fn mouse_move(x: i16, y: i16) void {
    events.enqueue(Event{ .MouseMove = .{
        .x = @intToFloat(f32, x),
        .y = @intToFloat(f32, y),
    } });
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

fn winPtrToIdx(window: *anyopaque) ?u32 {
    var iter = windows.iter();
    while (iter.nextIdx()) |wd| {
        if (@ptrToInt(wd.ret.window) == @ptrToInt(window)) {
            return @intCast(u32, wd.idx);
        }
    }
    return null;
}

export fn close_window(ptr: *anyopaque) void {
    const id: u32 = @truncate(u32, @ptrToInt(ptr));
    const idx = winPtrToIdx(ptr).?;
    log.info("closing {} ({x})", .{ idx, id });
    num_living -= 1;
    events.enqueue(Event{ .WindowClose = Handle(.Window){ .id = idx } });
}

export fn resize_window(ptr: *anyopaque, w: u16, h: u16) void {
    const idx = winPtrToIdx(ptr).?;
    events.enqueue(Event{
        .WindowResize = .{
            .handle = Handle(.Window){ .id = idx },
            // TODO: get x and y
            .x = 0,
            .y = 0,
            .w = w,
            .h = h,
        },
    });
}
