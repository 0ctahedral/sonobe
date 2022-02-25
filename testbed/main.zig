const std = @import("std");
const octal = @import("octal");
const Platform = octal.Platform;
const Renderer = octal.Renderer;
const Events = octal.Events;
const mmath = octal.mmath;

const app_name = "octal: triangle test";

const Game = struct {
    /// load resources and stuff
    pub fn init() void {}

    /// unload those resources?
    //pub fn deinit() void { }

    /// draw a frame?
    var f: f32 = 0;
    pub fn draw(window: anytype, dt: f32) void {
        _ = window;
        // window.framebuffer().submit?
        // submit data to renderer and stuff
        // scene.add(quad);
        // Renderer.submit(scene);
        f += dt;
        Renderer.updateUniform(mmath.Mat4.scale(mmath.Vec3.new(100, 100, 100))
            .mul(mmath.Mat4.rotate(.z, f))
            .mul(mmath.Mat4.translate(.{ .x = 350, .y = 250 + (@sin(f) * 100) })));
    }
};

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

    Game.init();

    var frame_timer = try std.time.Timer.start();

    while (Platform.is_running) {
        if (Platform.flush()) {
            if (try Renderer.beginFrame()) {
                Game.draw(.{}, @intToFloat(f32, frame_timer.read()) / @intToFloat(f32, std.time.ns_per_s));
                try Renderer.endFrame();
            }
        }

        frame_timer.reset();
    }
}
