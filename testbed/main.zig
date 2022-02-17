const std = @import("std");
const octal = @import("octal");
const Platform = octal.Platform;
const Renderer = octal.Renderer;
const mmath = octal.mmath;

//const glfw = @import("glfw");

const app_name = "octal: triangle test";

pub fn main() !void {
    // open the window
    try Platform.init(800, 600, app_name);
    defer Platform.deinit();

    const allocator = std.testing.allocator;

    // setup renderer
    try Renderer.init(allocator, app_name);
    defer Renderer.deinit();

    while (Platform.is_running) {
        try Platform.pollEvents();

        if (try Renderer.beginFrame()) {
            try Renderer.updateUniform(.{});
            try Renderer.endFrame();
        }
    }
}
