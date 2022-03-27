const std = @import("std");
const octal = @import("octal");
const Platform = octal.Platform;
const Renderer = octal.Renderer;
const Events = octal.Events;
const Vertex = Renderer.mesh.Vertex;
const Mesh = Renderer.mesh.Mesh;
const Quad = Renderer.mesh.Quad;
const mmath = octal.mmath;
const Mat4 = mmath.Mat4;
const Vec3 = mmath.Vec3;
const Buffer = Renderer.Buffer;

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

pub const MyConsts = struct {
    color: Vec3 = Vec3.new(1, 1, 0),
    index: u32,
};

// TODO: make a camera type
const CameraData = struct {
    projection: Mat4 = Mat4.perspective(mmath.util.rad(70), 800.0 / 600.0, 0.1, 1000),
    //projection: Mat4 = Mat4.ortho(0, 800.0, 0, 600.0, -100, 100),
    view: Mat4 = Mat4.translate(.{ .x = 0, .y = 0, .z = 2 }).inv(),
    //view: Mat4 = Mat4.translate(.{ .x = 0, .y = 0, .z = 0 }),
};


pub fn main() !void {
    // SETUP
    const allocator = std.testing.allocator;

    Events.init();
    errdefer Events.deinit();

    try Platform.init();
    errdefer Platform.deinit();

    const window = try Platform.createWindow(app_name, 800, 600);

    try Renderer.init(allocator, app_name, window);
    errdefer Renderer.deinit();

    // TODO: should this go in the platform?
    var frame_timer = try std.time.Timer.start();

    // create the buffers for scene data
    const vertex_buf_size = @sizeOf(Vertex) * 1024 * 1024;
    var vert_buf = try Renderer.buffer_manager.alloc();
    vert_buf.* = try Renderer.Buffer.init(Renderer.device, vertex_buf_size, .{
        .vertex_buffer_bit = true,
        .transfer_src_bit = true,
        .transfer_dst_bit = true,
    }, .{ .device_local_bit = true }, true);

    const index_buf_size = @sizeOf(u32) * 1024 * 1024;
    var ind_buf = try Renderer.buffer_manager.alloc();
    ind_buf.* = try Renderer.Buffer.init(Renderer.device, index_buf_size, .{
        .index_buffer_bit = true,
        .transfer_src_bit = true,
        .transfer_dst_bit = true,
    }, .{ .device_local_bit = true }, true);

    // upload to the buffers
    try vert_buf.stagedLoad(Vertex, octahedron_mesh.verts, 0);
    try ind_buf.stagedLoad(u32, octahedron_mesh.inds, 0);

    // create the renderpass
    var rpi = Renderer.RenderPassInfo{ .n_color_attachments = 1, .clear_flags = .{
        .color = true,
        .depth = true,
        .stencil = true,
    } };
    rpi.clear_colors[0] = .{ 0, 0.1, 0.0, 0 };

    rpi.clear_depth = .{
        .depth = 1.0,
        .stencil = 0,
    };

    // create the shader pipeline
    const pli1 = .{
        .resources = &.{
            .{
                .type = .uniform,
                .stage = .{ .vertex_bit = true },
            },
            .{
                .type = .storage,
                .stage = .{ .vertex_bit = true },
            },
        },

        .constants = &.{.{
            .size = @sizeOf(MyConsts),
            .stage = .{ .vertex_bit = true },
        }},

        .vertex = .{
            .path = "assets/builtin.vert.spv",
        },
        .fragment = .{
            .path = "assets/builtin.frag.spv",
        },
    };

    // used for rotating the octahedron
    var f: f32 = 0;

    // buffer for ssbo
    var model_buffer = try Buffer.init(Renderer.device, @sizeOf(Mat4), .{
        .storage_buffer_bit = true,
        .transfer_dst_bit = true,
    }, .{
        .host_visible_bit = true,
        .host_coherent_bit = true,
    }, true);

    var cam_data = CameraData{};

    while (Platform.is_running) {
        _ = Platform.flush();

        const dt = @intToFloat(f32, frame_timer.read()) / @intToFloat(f32, std.time.ns_per_s);
        frame_timer.reset();

        f += std.math.pi * dt;

        try Renderer.beginFrame();

        {
            // get the command buffer and start  it
            var cmd = &Renderer.getCurrentFrame().cmdbuf;
            try cmd.begin(.{});

            // get the current images for this frame
            rpi.color_attachments[0] = Renderer.swapchain.getCurrentImage();
            rpi.depth_attachment = &Renderer.swapchain.depth;

            // here we can change the clear color for some added interest
            rpi.clear_colors[0] = .{ 0, 0.1, (@sin(f) / 2.0) + 0.5, 0 };

            // start the renderpass
            try cmd.beginRenderPass(rpi);

            // use the shaders we declared earlier
            cmd.usePipeline(pli1);

            // set the model matrix for this object
            const model = Mat4.scale(Vec3.new(2, 2, 2))
                .mul(Mat4.rotate(.y, f))
                .mul(Mat4.translate(Vec3.new(0, 0, -10)));
            try model_buffer.load(Renderer.device, Mat4, &[_]Mat4{model}, 0);
            cmd.setBuffer(0, 1, model_buffer);

            // upload camera data for this frame
            // this is transient so in can use a uniform
            try cmd.allocUniform(0, 0, cam_data);

            cmd.pushConstant(0, MyConsts{ .index = 0, .color = Vec3.new(1, @sin(f), 0) });

            cmd.drawIndexed(octahedron_mesh.inds.len, vert_buf.*, ind_buf.*, 0, 0);

            cmd.endRenderPass();
            try cmd.end();
        }

        try Renderer.endFrame();
    }
}
