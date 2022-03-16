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

    const vertex_buf_size = @sizeOf(Vertex) * 1024 * 1024;
    var vert_buf = try Renderer.Buffer.init(Renderer.device, vertex_buf_size, .{
        .vertex_buffer_bit = true,
        .transfer_src_bit = true,
        .transfer_dst_bit = true,
    }, .{ .device_local_bit = true }, true);
    //defer vert_buf.deinit(Renderer.device);

    const index_buf_size = @sizeOf(u32) * 1024 * 1024;
    var ind_buf = try Renderer.Buffer.init(Renderer.device, index_buf_size, .{
        .index_buffer_bit = true,
        .transfer_src_bit = true,
        .transfer_dst_bit = true,
    }, .{ .device_local_bit = true }, true);
    //defer ind_buf.deinit(Renderer.device);


    // upload the vertices
    //try vert_buf.load(Renderer.device, Vertex, Quad.verts, 0);
    //try ind_buf.load(Renderer.device, u32, Quad.inds, 0);
    try vert_buf.stagedLoad(Vertex, octahedron_mesh.verts, 0);
    try ind_buf.stagedLoad(u32, octahedron_mesh.inds, 0);

    var rpi = Renderer.RenderPassInfo{
        .n_color_attachments = 1,
        .clear_flags = .{
            .color = true,
            .depth = true,
            .stencil = true,
        }
    };

    rpi.color_attachments[0] = &Renderer.swapchain.images[0];
    rpi.clear_colors[0] = .{  .float_32 = .{ 0, 0.1, 0, 0, } };

    rpi.depth_attachment = &Renderer.swapchain.depth;
    rpi.clear_depth = .{
        .depth = 1.0,
        .stencil = 0,
    };

    while (Platform.is_running) {
        _ = Platform.flush();

        const dt = @intToFloat(f32, frame_timer.read()) / @intToFloat(f32, std.time.ns_per_s);
        frame_timer.reset();
        f += std.math.pi * dt;

        try Renderer.beginFrame();

        {

            var cmd = &Renderer.getCurrentFrame().cmdbuf;
            try cmd.begin(.{});
            try cmd.beginRenderPass(rpi);

            Renderer.getCurrentFrame().*.model_data[0] = Mat4.scale(Vec3.new(2, 2, 2))
                .mul(Mat4.rotate(.y, f))
                //.mul(Mat4.translate(Vec3.new(350, 250 + @sin(f) * 100, 0)));
                .mul(Mat4.translate(Vec3.new(0, 0, -10)));

            // TODO: this will be part of the pipeline stuff
            try Renderer.getCurrentFrame().updateDescriptorSets();

            //cmd.pushConstant(Renderer.MeshPushConstants, Renderer.MeshPushConstants{ .index = 0 });

            //cmd.drawIndexed(Quad.inds.len, vert_buf, ind_buf, 0, 0);

            cmd.pushConstant(Renderer.MeshPushConstants, Renderer.MeshPushConstants{ .index = 0 });

            cmd.drawIndexed(octahedron_mesh.inds.len, vert_buf, ind_buf, 0, 0);

            cmd.endRenderPass();
            try cmd.end();

        }

        try Renderer.endFrame();
    }
}
