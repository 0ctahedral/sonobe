const std = @import("std");
const vk = @import("vulkan");
const glfw = @import("glfw");
const InstanceDispatch = @import("../renderer/vulkan/dispatch_types.zig").InstanceDispatch;
const Events = @import("../events.zig");
const Event = Events.Event;
const Input = @import("../input.zig");
const Window = @import("window.zig");
const RingBuffer = @import("../containers.zig").RingBuffer;
const FreeList = @import("../containers.zig").FreeList;

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
    // window.setKeyCallback(onKey);
    window.setMouseButtonCallback(onMouseButton);
    window.setCursorPosCallback(onMouseMove);
    window_store[id] = window;

    n_alive += 1;

    return Window{ .handle = @intToEnum(Window.Handle, id) };
}

pub fn setWindowTitle(win: Window, title: []const u8) !void {
    const window = window_store[@enumToInt(win.handle)];
    try window.setTitle(@ptrCast([*:0]const u8, title.ptr));
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

    Events.enqueue(.{ .MouseMove = .{
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

    const button: Input.Mouse.Button = switch (gbutton) {
        .left => .left,
        .right => .right,
        .middle => .middle,
        else => {
            return;
        },
    };

    const action: Input.Mouse.Action = switch (gaction) {
        .press, .repeat => .press,
        .release => .release,
    };

    const pos = win.getCursorPos() catch unreachable;

    Events.enqueue(.{
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
    std.log.debug("w: {}, k: {}, s: {}, a: {}, m: {}", .{
        win,
        key,
        scancode,
        action,
        mods,
    });
}

fn onResize(win: glfw.Window, ww: i32, wh: i32) void {
    if (getWindowIndex(win)) |wid| {
        Events.enqueue(Event{ .WindowResize = .{
            .handle = @intToEnum(Window.Handle, wid),
            .w = @intCast(u16, ww),
            .h = @intCast(u16, wh),
        } });
    }
}

fn onClose(win: glfw.Window) void {
    if (getWindowIndex(win)) |wid| {
        Events.enqueue(Event{ .WindowClose = @intToEnum(Window.Handle, wid) });
    }

    n_alive -= 1;
    if (n_alive == 0) {
        Events.enqueue(Event{ .Quit = .{} });
    }
}

pub fn flush() void {
    glfw.pollEvents() catch unreachable;
}

pub fn createWindowSurface(vki: InstanceDispatch, instance: vk.Instance, win: Window) !vk.SurfaceKHR {
    _ = vki;
    const idx = @enumToInt(win.handle);

    var surface: vk.SurfaceKHR = undefined;
    if ((try glfw.createWindowSurface(instance, window_store[idx], null, &surface)) != @enumToInt(vk.Result.success)) {
        return error.SurfaceInitFailed;
    }

    return surface;
}
