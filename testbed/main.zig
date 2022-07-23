const std = @import("std");
const octal = @import("octal");

const Renderer = octal.Renderer;
const Resources = octal.Renderer.Resources;
const Input = octal.Input;
const CmdBuf = Renderer.CmdBuf;

const mmath = octal.mmath;
const Vec3 = mmath.Vec3;
const Vec2 = mmath.Vec2;
const Quat = mmath.Quat;
const Mat4 = mmath.Mat4;
const Transform = mmath.Transform;

// since this file is implicitly a struct we can store state in here
// and use methods that we expect to be defined in the engine itself.
// we can then make our app a package which is included by the engine
const App = @This();

/// The name of this app (required)
pub const name = "testbed";

const positions = [_]Vec3{
    Vec3.new(-0.5, -0.5, 0),
    Vec3.new(0.5, 0.5, 0),
    Vec3.new(-0.5, 0.5, 0),
    Vec3.new(0.5, -0.5, 0),
};
const texcoords = [_]Vec2{
    Vec2.new(0.0, 0.0),
    Vec2.new(1.0, 1.0),
    Vec2.new(0.0, 1.0),
    Vec2.new(1.0, 0.0),
};
const quad_inds = [_]u32{ 0, 1, 2, 0, 3, 1 };

const UniformData = struct {
    projection: Mat4 align(16) = Mat4.perspective(mmath.util.rad(70), 800.0 / 600.0, 0.1, 1000),
    view: Mat4 align(16) = Mat4.translate(.{ .x = 0, .y = 0, .z = 10 }).inv(),
    model: Mat4 align(16) = Mat4.identity(),
};

// internal state of the app
/// angle that we have rotated the quad to
theta: f32 = 0,
/// transform of the quad
t: Transform = .{},

quad_verts: Renderer.Handle = .{},
quad_inds: Renderer.Handle = .{},
simple_pipeline: Renderer.Handle = .{},
world_pass: Renderer.Handle = .{},
uniform_buffer: Renderer.Handle = .{},
uniform_data: UniformData = .{},
simple_group: Renderer.Handle = .{},
default_texture: Renderer.Handle = .{},
default_sampler: Renderer.Handle = .{},

pub fn init(app: *App) !void {
    _ = app;
    std.log.info("{s}: initialized", .{App.name});

    app.t.pos = .{ .x = 0, .y = 0, .z = 0 };
    app.t.scale = .{ .x = 10, .y = 10, .z = 0 };

    // allocate buffer and upload data
    app.quad_verts = try Resources.createBuffer(
        .{
            .size = @sizeOf(@TypeOf(texcoords)) + @sizeOf(@TypeOf(positions)),
            .usage = .Vertex,
        },
    );
    var offset = try Renderer.updateBuffer(app.quad_verts, 0, Vec3, positions[0..]);
    offset = try Renderer.updateBuffer(app.quad_verts, offset, Vec2, texcoords[0..]);

    app.quad_inds = try Resources.createBuffer(
        .{
            .size = @sizeOf(@TypeOf(quad_inds)),
            .usage = .Index,
        },
    );
    _ = try Renderer.updateBuffer(app.quad_inds, 0, u32, quad_inds[0..]);

    app.uniform_buffer = try Resources.createBuffer(
        .{
            .size = @sizeOf(UniformData),
            .usage = .Uniform,
        },
    );
    _ = try Renderer.updateBuffer(app.uniform_buffer, 0, UniformData, &[_]UniformData{app.uniform_data});

    app.simple_group = try Resources.createBindingGroup(&.{
        .{ .binding_type = .Buffer },
        .{ .binding_type = .Texture },
        .{ .binding_type = .Sampler },
    });

    // create a texture
    // generate the pattern
    const tex_dimension: u32 = 256;
    const channels: u32 = 4;
    const pixel_count = tex_dimension * tex_dimension;
    var pixels: [pixel_count * channels]u8 = undefined;

    // set to 255
    for (pixels) |*p| {
        p.* = 255;
    }

    var row: usize = 0;
    while (row < tex_dimension) : (row += 1) {
        var col: usize = 0;
        while (col < tex_dimension) : (col += 1) {
            var index = (row * tex_dimension) + col;
            var index_bpp = index * channels;
            if ((col + row) % 4 != 0) {
                pixels[index_bpp + 0] = 0;
                pixels[index_bpp + 3] = 0;
            }
        }
    }

    app.default_texture = try Resources.createTexture(.{
        .width = tex_dimension,
        .height = tex_dimension,
        .channels = channels,
        .flags = .{},
    }, pixels[0..]);

    app.default_sampler = try Resources.createSampler(.{
        .filter = .bilinear,
        .repeat = .wrap,
        .compare = .greater,
    });

    // sets what resource this binding points to
    // aka writes to the descriptor set
    try Resources.updateBindings(app.simple_group, &[_]Resources.BindingUpdate{
        .{ .binding = 0, .handle = app.uniform_buffer },
        .{ .binding = 1, .handle = app.default_texture },
        .{ .binding = 2, .handle = app.default_sampler },
    });

    const rp_desc = .{
        .clear_color = .{ 0.75, 0.49, 0.89, 1.0 },
        .clear_depth = 1.0,
        .clear_stencil = 1.0,
        .clear_flags = .{
            .color = true,
            .depth = true,
        },
    };

    app.world_pass = try Resources.createRenderPass(rp_desc);

    // create our shader pipeline
    app.simple_pipeline = try Resources.createPipeline(.{
        .stages = &.{
            .{
                .bindpoint = .Vertex,
                .path = "assets/builtin.vert.spv",
            },
            .{
                .bindpoint = .Fragment,
                .path = "assets/builtin.frag.spv",
            },
        },
        .binding_groups = &.{app.simple_group},
        .renderpass = app.world_pass,
    });
}

pub fn update(app: *App, dt: f64) !void {
    app.theta += std.math.pi * @floatCast(f32, dt);
    app.t.rot = Quat.fromAxisAngle(Vec3.FORWARD, app.theta);
    app.uniform_data.model = app.t.mat();

    const left = Input.getMouse().getButton(.left);

    if (left.action == .release) {
        std.log.debug("drag: {d:.1} {d:.1}", .{ left.drag.x, left.drag.y });
    }

    // update a constant value from struct rather than entire thing?
    // this would have to be something in a struct
    // where we could update by offset
    // try Resources.updateConst(app.uniform_buffer, UniformData, .const_name, 35)
    _ = try Renderer.updateBuffer(app.uniform_buffer, 0, UniformData, &[_]UniformData{app.uniform_data});
}

pub fn render(app: *App) !void {
    var cmd = Renderer.getCmdBuf();

    try cmd.beginRenderPass(app.world_pass);

    try cmd.bindPipeline(app.simple_pipeline);

    try cmd.drawIndexed(.{
        .count = 6,
        .vertex_handle = app.quad_verts,
        .index_handle = app.quad_inds,
    });

    try cmd.endRenderPass(app.world_pass);

    try Renderer.submit(cmd);
}

pub fn deinit(app: *App) void {
    _ = app;
    std.log.info("{s}: deinitialized", .{App.name});
}
