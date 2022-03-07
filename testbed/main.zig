const std = @import("std");
const octal = @import("octal");
const Platform = octal.Platform;
const Renderer = octal.Renderer;
const Events = octal.Events;
const Mesh = Renderer.mesh.Mesh;
const mmath = octal.mmath;
const Mat4 = mmath.Mat4;
const Vec3 = mmath.Vec3;
const vk = Renderer.vk;

const app_name = "octal: triangle test";

const octahedron_mesh = Mesh{
    .verts = &.{
        .{ .pos = .{ .x = -1.1920928955078125e-07, .y = -1.1920928955078125e-07, .z = -1.0 } },
        .{ .pos = .{ .x = -1.1920928955078125e-07, .y = -1.0, .z = -1.1920928955078125e-07 } },
        .{ .pos = .{ .x = -1.0, .y = -1.1920928955078125e-07, .z = -1.1920928955078125e-07 } },
        .{ .pos = .{ .x = -1.1920928955078125e-07, .y = -1.1920928955078125e-07, .z = 1.0 } },
        .{ .pos = .{ .x = -1.1920928955078125e-07, .y = 1.0, .z = -1.1920928955078125e-07 } },
        .{ .pos = .{ .x = 1.0, .y = -1.1920928955078125e-07, .z = -1.1920928955078125e-07 } },
        .{ .pos = .{ .x = -0.6666668057441711, .y = -0.6666667461395264, .z = -0.6666667461395264 } },
        .{ .pos = .{ .x = -0.6666668057441711, .y = -0.6666667461395264, .z = 0.6666667461395264 } },
        .{ .pos = .{ .x = -0.6666667461395264, .y = 0.6666668057441711, .z = -0.6666667461395264 } },
        .{ .pos = .{ .x = -0.6666668057441711, .y = 0.6666667461395264, .z = 0.6666667461395264 } },
        .{ .pos = .{ .x = 0.6666667461395264, .y = -0.6666668057441711, .z = -0.6666667461395264 } },
        .{ .pos = .{ .x = 0.6666668057441711, .y = -0.6666667461395264, .z = 0.6666667461395264 } },
        .{ .pos = .{ .x = 0.6666668057441711, .y = 0.6666667461395264, .z = -0.6666667461395264 } },
        .{ .pos = .{ .x = 0.6666667461395264, .y = 0.6666668057441711, .z = 0.6666667461395264 } },
    },

    .inds = &.{ 0, 1, 6, 1, 3, 7, 0, 2, 8, 3, 4, 9, 0, 5, 10, 3, 1, 11, 0, 4, 12, 3, 5, 13, 1, 2, 6, 2, 0, 6, 3, 2, 7, 2, 1, 7, 2, 4, 8, 4, 0, 8, 4, 2, 9, 2, 3, 9, 5, 1, 10, 1, 0, 10, 1, 5, 11, 5, 3, 11, 4, 5, 12, 5, 0, 12, 5, 4, 13, 4, 3, 13 },
};

const Game = struct {
    //var pl_handle: Renderer.PipelineHandle = .null_handle;
    /// load resources and stuff
    pub fn init() void {
        // setup pipeline
        // should this be a material declaration?
        // or are materials separate?
        //pl_handle = Renderer.createPipeline(
        //// TODO: vertex type?
        //// stages
        //.{
        //    .vertex = "assets/builtin.vert.spv",
        //    .fragment = "assets/builtin.frag.spv",
        //    //.compute = "",
        //});
        // inputs and outputs?
    }

    /// unload those resources?
    pub fn deinit() void {}

    /// draw a frame
    /// basically records and submits a single draw call?
    var f: f32 = 0;
    pub fn draw(window: anytype, dt: f32) void {
        _ = window;
        //Renderer.setPipeline(pl_handle);
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

    var frame_timer = try std.time.Timer.start();

    var f: f32 = 0;

    while (Platform.is_running) {
        if (Platform.flush()) {

            const dt = @intToFloat(f32, frame_timer.read()) / @intToFloat(f32, std.time.ns_per_s);
            frame_timer.reset();
            f += std.math.pi * dt;

            try Renderer.beginFrame();

            {

            var cmd = &Renderer.getCurrentFrame().cmdbuf;
            try cmd.begin(.{});
            cmd.beginRenderPass(Renderer.renderpass);

            Renderer.getCurrentFrame().*.model_data[0] = mmath.Mat4.scale(Vec3.new(100, 100, 100))
            .mul(Mat4.rotate(.z, f))
            .mul(Mat4.translate(.{ .x = 350, .y = 250 + (@sin(f) * 100) }));
            try Renderer.getCurrentFrame().updateDescriptorSets();

            cmd.pushConstant(Renderer.MeshPushConstants, Renderer.MeshPushConstants{ .index = 0 });

            cmd.drawIndexed(Renderer.quad.inds.len);

            cmd.pushConstant(Renderer.MeshPushConstants, Renderer.MeshPushConstants{ .index = 1 });

            cmd.drawIndexed(Renderer.quad.inds.len);

            cmd.endRenderPass();
            try cmd.end();

            }

            try Renderer.endFrame();
        }

    }
}
