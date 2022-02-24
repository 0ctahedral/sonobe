const std = @import("std");
const octal = @import("octal");
const Platform = octal.Platform;
const Renderer = octal.Renderer;
const Events = octal.Events;
const mmath = octal.mmath;

const app_name = "octal: triangle test";

pub fn main() !void {
    // initialize the event system
    Events.init();
    defer Events.deinit();


    // open the window
    try Platform.init();
    defer Platform.deinit();
    errdefer Platform.deinit();



    const window = try Platform.createWindow(app_name, 800, 600);
    _ = window;

    //// setup renderer
    const allocator = std.testing.allocator;
    try Renderer.init(allocator, app_name, window);
    defer Renderer.deinit();

    var f: f32 = 0;

    while (Platform.is_running) {
        if (Platform.flush()) {
            if (try Renderer.beginFrame()) {
                try Renderer.updateUniform(
                        mmath.Mat4.scale(mmath.Vec3.new(100, 100, 100))
                            .mul(mmath.Mat4.rotate(.z, f))
                            .mul(mmath.Mat4.translate(.{ .x = 350, .y = 250 + (@sin(f) * 100)}))
                    );
                try Renderer.endFrame();
            }
        }

        f += 0.033;
    }

}
