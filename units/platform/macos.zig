const std = @import("std");
const Handle = @import("utils").Handle;
const FreeList = @import("containers").FreeList;
const Vec2 = @import("math").Vec2;
const log = @import("utils").log.default;
const events = @import("events.zig");
const input = @import("input.zig");
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

export fn key_down(keycode: u32) void {
    input.setKeyState(Event{
        .KeyPress = translate_keycode(keycode),
    });
}

export fn key_up(keycode: u32) void {
    input.setKeyState(Event{
        .KeyRelease = translate_keycode(keycode),
    });
}

export fn modifier_keys(
    keycode: u32,
    modifier: u32,
    shift: u32,
    ctrl: u32,
    alt: u32,
    super: u32,
) void {
    _ = modifier;
    const key = translate_keycode(keycode);
    const ev: Event = switch (key) {
        .l_shift,
        .r_shift,
        => if (shift > 0) .{ .KeyPress = key } else .{ .KeyRelease = key },
        .l_ctrl,
        .r_ctrl,
        => if (ctrl > 0) .{ .KeyPress = key } else .{ .KeyRelease = key },
        .l_alt,
        .r_alt,
        => if (alt > 0) .{ .KeyPress = key } else .{ .KeyRelease = key },
        .l_super,
        .r_super,
        => if (super > 0) .{ .KeyPress = key } else .{ .KeyRelease = key },
        else => unreachable,
    };

    input.setModifier(ev);
}

inline fn translate_keycode(ns_keycode: u32) input.Key {
    return switch (ns_keycode) {
        0x1D => .n0,
        0x12 => .n1,
        0x13 => .n2,
        0x14 => .n3,
        0x15 => .n4,
        0x17 => .n5,
        0x16 => .n6,
        0x1A => .n7,
        0x1C => .n8,
        0x19 => .n9,

        0x00 => .a,
        0x0B => .b,
        0x08 => .c,
        0x02 => .d,
        0x0E => .e,
        0x03 => .f,
        0x05 => .g,
        0x04 => .h,
        0x22 => .i,
        0x26 => .j,
        0x28 => .k,
        0x25 => .l,
        0x2E => .m,
        0x2D => .n,
        0x1F => .o,
        0x23 => .p,
        0x0C => .q,
        0x0F => .r,
        0x01 => .s,
        0x11 => .t,
        0x20 => .u,
        0x09 => .v,
        0x0D => .w,
        0x07 => .x,
        0x10 => .y,
        0x06 => .z,
        0x27 => .apostrophe,
        0x2A => .backslash,
        0x2B => .comma,
        0x18 => .equal,
        0x32 => .grave,
        0x21 => .left_bracket, // Left bracket
        0x1B => .minus,
        0x2F => .period,
        0x1E => .right_bracket, // Right bracket
        0x29 => .semicolon,
        0x2C => .slash,
        // 0x0A => .quest, // ?
        0x33 => .backspace,
        // 0x39 => KEY_CAPITAL,
        0x75 => .delete,
        0x77 => .end,
        0x24 => .enter,
        0x35 => .escape,
        0x7A => .f1,
        0x78 => .f2,
        0x63 => .f3,
        0x76 => .f4,
        0x60 => .f5,
        0x61 => .f6,
        0x62 => .f7,
        0x64 => .f8,
        0x65 => .f9,
        0x6D => .f10,
        0x67 => .f11,
        0x6F => .f12,
        0x6B => .f14,
        0x71 => .f15,
        0x6A => .f16,
        0x40 => .f17,
        0x4F => .f18,
        0x50 => .f19,
        0x5A => .f20,
        0x69 => .print,
        0x73 => .home,
        0x72 => .insert,
        0x7E => .up,
        0x7D => .down,
        0x7B => .left,
        0x7C => .right,
        0x3A => .l_alt,
        0x3B => .l_ctrl,
        0x38 => .l_shift,
        0x37 => .l_super,
        0x3d => .r_alt,
        0x3e => .r_ctrl,
        0x3c => .r_shift,
        0x36 => .r_super,
        0x6E => .menu, // Menu
        // 0x47 => KEY_NUMLOCK,
        0x79 => .page_down, // Page down
        0x74 => .page_up, // Page up
        0x31 => .space,
        0x30 => .tab,

        0x52 => .kp_0,
        0x53 => .kp_1,
        0x54 => .kp_2,
        0x55 => .kp_3,
        0x56 => .kp_4,
        0x57 => .kp_5,
        0x58 => .kp_6,
        0x59 => .kp_7,
        0x5B => .kp_8,
        0x5C => .kp_9,
        0x45 => .add,
        0x41 => .decimal,
        0x4B => .divide,
        0x4C => .enter,
        0x51 => .equal,
        0x43 => .subtract,
        0x4E => .multiply,
        else => .unknown,
    };
}
