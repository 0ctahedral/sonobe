const std = @import("std");
const octal = @import("octal");
const cube = octal.mesh.cube;
const quad = octal.mesh.quad;

const renderer = octal.renderer;
const resources = octal.renderer.resources;
const input = octal.input;
const jobs = octal.jobs;
const CmdBuf = renderer.CmdBuf;

const mmath = octal.mmath;
const Vec4 = mmath.Vec4;
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
pub const name = "font";

/// renderpass for drawing to the screen
screen_pass: renderer.Handle = .{},

/// quad for fonts
quad_verts: renderer.Handle = .{},
quad_inds: renderer.Handle = .{},

/// bindgroup for the font
font_group: renderer.Handle = .{},
/// buffer containing the orthographic matrix?
/// later it will contain the offsets of the glyphs
font_buffer: renderer.Handle = .{},
/// texture containing all the glyphs
font_texture: renderer.Handle = .{},
/// sampler for above texture
font_sampler: renderer.Handle = .{},
/// pipeline for rendering fonts
font_pipeline: renderer.Handle = .{},

pub fn init(app: *App) !void {
    // setup the quad
    app.quad_verts = try resources.createBuffer(
        .{
            .size = quad.uvs.len * @sizeOf(Vec2) + quad.positions.len * @sizeOf(Vec3),
            .usage = .Vertex,
        },
    );
    var offset = try renderer.updateBuffer(app.quad_verts, 0, Vec3, quad.positions);
    offset = try renderer.updateBuffer(app.quad_verts, offset, Vec2, quad.uvs);

    app.quad_inds = try resources.createBuffer(
        .{
            .size = quad.indices.len * @sizeOf(u32),
            .usage = .Index,
        },
    );
    _ = try renderer.updateBuffer(app.quad_inds, 0, u32, quad.indices);

    // setup the material
    app.font_group = try resources.createBindingGroup(&.{
        .{ .binding_type = .Buffer },
        .{ .binding_type = .Texture },
        .{ .binding_type = .Sampler },
    });

    app.font_buffer = try resources.createBuffer(
        .{
            .size = 1024,
            .usage = .Uniform,
        },
    );
    // _ = try renderer.updateBuffer(app.material_buffer, 0, MaterialData, &[_]MaterialData{app.material_data});

    const tex_dimension: u32 = 16;
    const channels: u32 = 1;
    var pixels: [tex_dimension * tex_dimension * channels]u8 = .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 255, 255, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 255, 255, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 255, 255, 255, 255, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 255, 255, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 255, 255, 255, 255, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 255, 255, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 255, 255, 255, 255, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 255, 255, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 255, 255, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };

    app.font_texture = try resources.createTexture(.{
        .width = tex_dimension,
        .height = tex_dimension,
        .channels = channels,
        .flags = .{},
        .texture_type = .@"2d",
    }, &pixels);

    app.font_sampler = try resources.createSampler(.{
        .filter = .nearest,
        .repeat = .wrap,
        .compare = .greater,
    });

    try resources.updateBindings(app.font_group, &[_]resources.BindingUpdate{
        .{ .binding = 0, .handle = app.font_buffer },
        .{ .binding = 1, .handle = app.font_texture },
        .{ .binding = 2, .handle = app.font_sampler },
    });

    app.screen_pass = try resources.createRenderPass(.{
        .clear_color = .{ 0.75, 0.49, 0.89, 1.0 },
        .clear_depth = 1.0,
        .clear_stencil = 1.0,
        .clear_flags = .{ .depth = true, .color = true },
    });

    // create our shader pipeline
    app.font_pipeline = try resources.createPipeline(.{
        .stages = &.{
            .{
                .bindpoint = .Vertex,
                .path = "font_example/assets/font.vert.spv",
            },
            .{
                .bindpoint = .Fragment,
                .path = "font_example/assets/font.frag.spv",
            },
        },
        .binding_groups = &.{app.font_group},
        .renderpass = app.screen_pass,
        .cull_mode = .none,
        .vertex_inputs = &.{ .Vec3, .Vec2 },
        .push_const_size = 2 * @sizeOf(Mat4),
    });
}

pub fn update(_: *App, _: f64) !void {}

pub fn render(app: *App) !void {
    var cmd = renderer.getCmdBuf();

    try cmd.beginRenderPass(app.screen_pass);

    try cmd.bindPipeline(app.font_pipeline);

    // draw the floor
    try cmd.pushConst(app.font_pipeline, [_]Mat4{
        Mat4.ortho(0, 800, 0, 600, 0.1, 10),
        Mat4.scale(Vec3.new(100, 100, 1)).mul(Mat4.translate(Vec3.new(-1, 0.0, 0.5))),
    });

    try cmd.drawIndexed(.{
        .count = quad.indices.len,
        .vertex_handle = app.quad_verts,
        .index_handle = app.quad_inds,
        .offsets = &.{ 0, 4 * @sizeOf(Vec3) },
    });

    try cmd.endRenderPass(app.screen_pass);

    try renderer.submit(cmd);
}

pub fn deinit(app: *App) void {
    _ = app;
    std.log.info("{s}: deinitialized", .{App.name});
}

pub fn onResize(app: *App, w: u16, h: u16) void {
    _ = app;
    _ = h;
    _ = w;
    // app.camera.aspect = @intToFloat(f32, w) / @intToFloat(f32, h);
}
