const std = @import("std");
const vk = @import("vulkan");
const glfw = @import("glfw");
const InstanceDispatch = @import("../renderer/vulkan/dispatch_types.zig").InstanceDispatch;
const Event = @import("../events.zig").Event;
const Window = @import("window.zig");
const RingBuffer = @import("../containers.zig").RingBuffer;
const FreeList = @import("../containers.zig").FreeList;

/// the window we are using
// pub var default_window: glfw.Window = undefined;

var events: RingBuffer(Event, 32) = undefined;
var windows: FreeList(glfw.Window) = undefined;
var window_store: [10]glfw.Window = undefined;
var n_alive: usize = 0;

pub fn init() !void {
    try glfw.init(.{});
    events = RingBuffer(Event, 32).init();
    windows = try FreeList(glfw.Window).initArena(&window_store);
}

pub fn deinit() void {
    events.deinit();
    glfw.terminate();
}

pub fn createWindow(title: []const u8, w: u32, h: u32) !Window {
    const id: u32 = try windows.allocIndex();
    const window = try glfw.Window.create(w, h, @ptrCast([*:0]const u8, title.ptr), null, null, .{
        .client_api = .no_api,
        .floating = true,
    });
    window.setSizeCallback(resize);
    window.setCloseCallback(close);
    window_store[id] = window;

    n_alive += 1;

    return Window{ .handle = @intToEnum(Window.Handle, id) };
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

fn resize(win: glfw.Window, ww: i32, wh: i32) void {
    if (getWindowIndex(win)) |wid| {
        events.push(Event{ .WindowResize = .{
            .handle = @intToEnum(Window.Handle, wid),
            .w = @intCast(u16, ww),
            .h = @intCast(u16, wh),
        } }) catch {
            std.log.warn("dropping event", .{});
        };
    }
}

fn close(win: glfw.Window) void {
    if (getWindowIndex(win)) |wid| {
        events.push(Event{ .WindowClose = @intToEnum(Window.Handle, wid) }) catch {
            std.log.warn("dropping event", .{});
        };
    }

    n_alive -= 1;
    if (n_alive == 0) {
        events.push(Event{ .Quit = .{} }) catch {
            // need to make sure that we add this event so we discard one
            _ = events.pop();
            events.push(Event{ .Quit = .{} }) catch unreachable;
        };
    }
}

pub fn nextEvent() ?Event {
    glfw.pollEvents() catch unreachable;
    if (events.pop()) |e| {
        return e;
    }

    return null;
}

pub fn createWindowSurface(vki: InstanceDispatch, instance: vk.Instance, win: Window) !vk.SurfaceKHR {
    _ = vki;
    const idx = @enumToInt(win.handle);

    std.log.debug("window to surface: {}", .{win});
    std.log.debug("windows: {any}", .{window_store});

    var surface: vk.SurfaceKHR = undefined;
    if ((try glfw.createWindowSurface(instance, window_store[idx], null, &surface)) != @enumToInt(vk.Result.success)) {
        return error.SurfaceInitFailed;
    }

    return surface;
}
