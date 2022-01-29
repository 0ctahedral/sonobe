const std = @import("std");
const Renderer = @import("renderer.zig");
const vk = @import("vulkan");
const glfw = @import("glfw");

const app_name = "octal: triangle test";

fn cb(g: glfw.Window, w: i32, h: i32) void {
    _ = g;
    std.log.info("w: {}, h: {}", .{w, h});
    Renderer.resize(@intCast(u32, w), @intCast(u32, h));
}

pub fn main() !void {
    // open the window
    // TODO: replace this with system function
    try glfw.init(.{});
    defer glfw.terminate();

    var extent = vk.Extent2D{ .width = 800, .height = 600 };

    const window = try glfw.Window.create(extent.width, extent.height, app_name, null, null, .{
        .client_api = .no_api,
        .floating = true,
    });
    defer window.destroy();

    //const allocator = std.heap.page_allocator;
    const allocator = std.testing.allocator;

    // setup renderer
    try Renderer.init(allocator, app_name, window);
    defer Renderer.deinit();

    window.setSizeCallback(cb);


    while (!window.shouldClose()) {
        try glfw.pollEvents();
        if (try Renderer.beginFrame()) {
            try Renderer.endFrame();
        }
    }
}
