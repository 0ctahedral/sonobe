const std = @import("std");
const vk = @import("vulkan");
const glfw = @import("glfw");
const Renderer = @import("renderer.zig");

/// the window we are using
pub var window: glfw.Window = undefined;

pub var is_running = false;

pub fn init(width: u32, height: u32, app_name: [*:0]const u8) !void {
    try glfw.init(.{});
    window = try glfw.Window.create(width, height, app_name, null, null, .{
        .client_api = .no_api,
        .floating = true,
    });

    window.setSizeCallback(cb);

    is_running = true;
}

const Size = struct { w: i32, h: i32 };

var resized: ?Size = null;

// TODO: this should be adding a resize event to a queue
fn cb(g: glfw.Window, w: i32, h: i32) void {
    _ = g;
    resized = .{ .w = w, .h = h };
}

pub fn pollEvents() !void {
    try glfw.pollEvents();
    if (resized) |s| {
        std.log.info("w: {}, h: {}", .{ s.w, s.h });
        Renderer.resize(@intCast(u32, s.w), @intCast(u32, s.h));
        resized = null;
    }
    is_running = !window.shouldClose();
}

pub fn deinit() void {
    window.destroy();
    glfw.terminate();
}

pub fn getInstanceProcAddress() fn (vk.Instance, [*:0]const u8) callconv(.C) vk.PfnVoidFunction {
    return @ptrCast(fn (instance: vk.Instance, procname: [*:0]const u8) callconv(.C) vk.PfnVoidFunction, glfw.getInstanceProcAddress);
}

pub fn createWindowSurface(instance: vk.Instance, surface: *vk.SurfaceKHR) !void {
    if ((try glfw.createWindowSurface(instance, window, null, surface)) != @enumToInt(vk.Result.success)) {
        return error.SurfaceInitFailed;
    }
}

pub fn getWinSize() !glfw.Window.Size {
    return try window.getSize();
}
