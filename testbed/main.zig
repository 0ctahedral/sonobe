const std = @import("std");
const octal = @import("octal");
const Platform = octal.Platform;
const Renderer = octal.Renderer;
const mmath = octal.mmath;

const app_name = "octal: triangle test";

pub fn main() !void {
    // open the window
    try Platform.init();
    defer Platform.deinit();
    errdefer Platform.deinit();

    const allocator = std.testing.allocator;


    const window = try Platform.createWindow(app_name, 800, 600);
    _ = window;

    //// setup renderer
    try Renderer.init(allocator, app_name, window);
    defer Renderer.deinit();

    while (Platform.is_running) {
        if (Platform.flush()) {
            if (try Renderer.beginFrame()) {
                try Renderer.updateUniform(.{});
                try Renderer.endFrame();
            }
        }
    }

}
