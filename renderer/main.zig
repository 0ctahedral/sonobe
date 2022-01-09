const std = @import("std");
const renderer = @import("renderer.zig");
const vk = @import("vulkan");
const glfw = @import("glfw");

const app_name = "octal: triangle test";

pub fn main() !void {
    // open the window
    // TODO: replace this with system function
    try glfw.init(.{});
    defer glfw.terminate();

    var extent = vk.Extent2D{ .width = 800, .height = 600 };

    const window = try glfw.Window.create(extent.width, extent.height, app_name, null, null, .{
        .client_api = .no_api,
    });
    defer window.destroy();

    while (!window.shouldClose()) {
        try glfw.pollEvents();
    }
}
