const std = @import("std");
const octal = @import("octal");
const Platform = octal.Platform;
const Renderer = octal.Renderer;
const Events = octal.Events;
const mmath = octal.mmath;
const Vec3 = mmath.Vec3;
const Quat = mmath.Quat;
const Transform = mmath.Transform;

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

    var t = mmath.Transform{};
    t.pos = .{ .x = 0, .y = 0, .z = 0 };
    t.scale = .{ .x = 10, .y = 10, .z = 0 };

    while (Platform.is_running) {
        if (Platform.flush()) {
            if (try Renderer.beginFrame()) {
                //t.rot = mmath.Quat.fromAxisAngle(Vec3.FORWARD, f);
                //try Renderer.updateUniform(t.mat());
                Renderer.push_constant.model = t.mat();
                try Renderer.endFrame();
            }
        }

        f += 0.033;
    }
}
