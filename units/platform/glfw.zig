const std = @import("std");
const vk = @import("vulkan");
const Handle = @import("utils").Handle;
const glfw = @import("glfw");
// TODO: get rid of this dep
const InstanceDispatch = @import("../device/vulkan/dispatch_types.zig").InstanceDispatch;
const events = @import("events.zig");
const Event = events.Event;
const input = @import("input.zig");
const Key = input.Key;
const Window = @import("window.zig");
const containers = @import("containers");
const FreeList = containers.FreeList;

var windows: FreeList(glfw.Window) = undefined;
var window_store: [10]glfw.Window = undefined;
var n_alive: usize = 0;

pub fn init() !void {
    try glfw.init(.{});
    windows = try FreeList(glfw.Window).initArena(&window_store);
}

pub fn deinit() void {
    glfw.terminate();
}

pub fn createWindow(title: []const u8, w: u32, h: u32) !Window {
    const id: u32 = try windows.allocIndex();
    const window = try glfw.Window.create(w, h, @ptrCast([*:0]const u8, title.ptr), null, null, .{
        .client_api = .no_api,
        .floating = true,
    });
    window.setSizeCallback(onResize);
    window.setCloseCallback(onClose);
    window.setKeyCallback(onKey);
    window.setMouseButtonCallback(onMouseButton);
    window.setCursorPosCallback(onMouseMove);
    window_store[id] = window;

    n_alive += 1;

    return Window{ .handle = Handle(.Window){ .id = id } };
}

pub fn setWindowTitle(win: Window, title: []const u8) !void {
    const window = window_store[@as(usize, win.handle)];
    try window.setTitle(@ptrCast([*:0]const u8, title.ptr));
}

pub fn getWindowSize(win: Window) !Window.Size {
    const window = window_store[@as(usize, win.handle.id)];
    const size = try window.getSize();
    return Window.Size{ .w = size.width, .h = size.height };
}

fn getWindowIndex(window: glfw.Window) ?u32 {
    var iter = windows.iter();
    while (iter.next()) |wd| {
        if (@ptrToInt(window.handle) == @ptrToInt(wd.handle)) {
            return @intCast(u32, iter.i);
        }
    }
    return null;
}

fn onMouseMove(
    win: glfw.Window,
    x: f64,
    y: f64,
) void {
    _ = win;

    events.enqueue(.{ .MouseMove = .{
        .x = @floatCast(f32, x),
        .y = @floatCast(f32, y),
    } });
}

fn onMouseButton(
    win: glfw.Window,
    gbutton: glfw.mouse_button.MouseButton,
    gaction: glfw.Action,
    gmods: glfw.Mods,
) void {
    _ = win;
    _ = gmods;

    const button: input.Mouse.Button = switch (gbutton) {
        .left => .left,
        .right => .right,
        .middle => .middle,
        else => {
            return;
        },
    };

    const action: input.Mouse.Action = switch (gaction) {
        .press, .repeat => .press,
        .release => .release,
    };

    const pos = win.getCursorPos() catch unreachable;

    events.enqueue(.{
        .MouseButton = .{
            .pos = .{
                .x = @floatCast(f32, pos.xpos),
                .y = @floatCast(f32, pos.ypos),
            },
            .button = button,
            .action = action,
        },
    });
}

fn onKey(
    win: glfw.Window,
    key: glfw.Key,
    scancode: i32,
    action: glfw.Action,
    mods: glfw.Mods,
) void {
    _ = win;
    _ = scancode;
    _ = action;
    _ = mods;
    if (action == .press) {
        events.enqueue(.{ .KeyPress = glfwKeyToInputKey(key) });
    } else if (action == .release) {
        events.enqueue(.{ .KeyRelease = glfwKeyToInputKey(key) });
    }
}

fn onResize(win: glfw.Window, ww: i32, wh: i32) void {
    if (getWindowIndex(win)) |wid| {
        events.enqueue(Event{ .WindowResize = .{
            .handle = Handle(.Window){ .id = wid },
            .w = @intCast(u16, ww),
            .h = @intCast(u16, wh),
        } });
    }
}

fn onClose(win: glfw.Window) void {
    if (getWindowIndex(win)) |wid| {
        events.enqueue(Event{
            .WindowClose = Handle(.Window){ .id = wid },
        });
    }

    n_alive -= 1;
    if (n_alive == 0) {
        events.enqueue(Event{ .Quit = .{} });
    }
}

pub fn flush() void {
    glfw.pollEvents() catch unreachable;
}

pub fn createWindowSurface(vki: InstanceDispatch, instance: vk.Instance, win: Window) !vk.SurfaceKHR {
    _ = vki;
    const idx = @as(usize, win.handle.id);

    var surface: vk.SurfaceKHR = undefined;
    if ((try glfw.createWindowSurface(instance, window_store[idx], null, &surface)) != @enumToInt(vk.Result.success)) {
        return error.SurfaceInitFailed;
    }

    return surface;
}

fn glfwKeyToInputKey(key: glfw.Key) Key {
    return switch (key) {
        .space => .space,
        .apostrophe => .apostrophe,
        .comma => .comma,
        .minus => .minus,
        .period => .period,
        .slash => .slash,
        .zero => .n0,
        .one => .n1,
        .two => .n2,
        .three => .n3,
        .four => .n4,
        .five => .n5,
        .six => .n6,
        .seven => .n7,
        .eight => .n8,
        .nine => .n9,
        .semicolon => .semicolon,
        .equal => .equal,
        .a => .a,
        .b => .b,
        .c => .c,
        .d => .d,
        .e => .e,
        .f => .f,
        .g => .g,
        .h => .h,
        .i => .i,
        .j => .j,
        .k => .k,
        .l => .l,
        .m => .m,
        .n => .n,
        .o => .o,
        .p => .p,
        .q => .q,
        .r => .r,
        .s => .s,
        .t => .t,
        .u => .u,
        .v => .v,
        .w => .w,
        .x => .x,
        .y => .y,
        .z => .z,
        .left_bracket => .left_bracket,
        .backslash => .backslash,
        .right_bracket => .right_bracket,
        .grave_accent => .grave,
        .world_1 => .world_1,
        .world_2 => .world_2,

        // Function keys
        .escape => .escape,
        .enter => .enter,
        .tab => .tab,
        .backspace => .backspace,
        .insert => .insert,
        .delete => .delete,
        .right => .right,
        .left => .left,
        .down => .down,
        .up => .up,
        .page_up => .page_up,
        .page_down => .page_down,
        .home => .home,
        .end => .end,
        .caps_lock => .caps_lock,
        .scroll_lock => .scroll_lock,
        .num_lock => .num_lock,
        .print_screen => .print,
        .pause => .pause,
        .F1 => .f1,
        .F2 => .f2,
        .F3 => .f3,
        .F4 => .f4,
        .F5 => .f5,
        .F6 => .f6,
        .F7 => .f7,
        .F8 => .f8,
        .F9 => .f9,
        .F10 => .f10,
        .F11 => .f11,
        .F12 => .f12,
        .F13 => .f13,
        .F14 => .f14,
        .F15 => .f15,
        .F16 => .f16,
        .F17 => .f17,
        .F18 => .f18,
        .F19 => .f19,
        .F20 => .f20,
        .F21 => .f21,
        .F22 => .f22,
        .F23 => .f23,
        .F24 => .f24,
        .F25 => .f25,
        .kp_0 => .kp_0,
        .kp_1 => .kp_1,
        .kp_2 => .kp_2,
        .kp_3 => .kp_3,
        .kp_4 => .kp_4,
        .kp_5 => .kp_5,
        .kp_6 => .kp_6,
        .kp_7 => .kp_7,
        .kp_8 => .kp_8,
        .kp_9 => .kp_9,
        .kp_decimal => .decimal,
        .kp_divide => .divide,
        .kp_multiply => .multiply,
        .kp_subtract => .subtract,
        .kp_add => .add,
        .kp_enter => .enter,
        .kp_equal => .equal,
        .left_shift => .l_shift,
        .left_control => .l_control,
        .left_alt => .l_alt,
        .left_super => .l_super,
        .right_shift => .r_shift,
        .right_control => .r_control,
        .right_alt => .r_alt,
        .right_super => .r_super,
        .menu => .menu,
        else => .unknown,
    };
}
