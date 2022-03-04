const std = @import("std");
const octal = @import("octal");
const Platform = octal.Platform;
const Renderer = octal.Renderer;
const Events = octal.Events;
const mmath = octal.mmath;

const app_name = "octal: triangle test";

const Game = struct {
    var pl_handle: Renderer.PipelineHandle = .null_handle;
    /// load resources and stuff
    pub fn init() void {
        // setup pipeline
        // should this be a material declaration?
        // or are materials separate?
        pl_handle = Renderer.createPipeline(
        // TODO: vertex type?
        // stages
        .{
            .vertex = "",
            .fragment = "",
            //.compute = "",
        });
        // inputs and outputs?
    }

    /// unload those resources?
    pub fn deinit() void {}

    /// draw a frame
    /// basically records and submits a single draw call?
    var f: f32 = 0;
    pub fn draw(window: anytype, dt: f32) void {
        _ = window;
        Renderer.setPipeline(pl_handle);
        // window.framebuffer().submit?
        // submit data to renderer and stuff
        // scene.add(quad);
        // Renderer.submit(scene);
        f += std.math.pi * dt;
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
    defer Game.deinit();

    var frame_timer = try std.time.Timer.start();

    while (Platform.is_running) {
        if (Platform.flush()) {
            if (try Renderer.beginFrame()) {
                const ftime = @intToFloat(f32, frame_timer.read()) / @intToFloat(f32, std.time.ns_per_s);
                Game.draw(.{}, ftime);
                try Renderer.endFrame();
                //std.log.debug("ftime: {}", .{std.time.ns_per_s / frame_timer.read()});
            }
        }

        frame_timer.reset();
    }
}
