const std = @import("std");
const octal = @import("octal");

const Renderer = octal.Renderer;
const CmdBuf = Renderer.CmdBuf;

const mmath = octal.mmath;
const Vec3 = mmath.Vec3;
const Vec2 = mmath.Vec2;
const Quat = mmath.Quat;
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

// internal state of the app
/// angle that we have rotated the quad to
theta: f32 = 0,
/// transform of the quad
t: Transform = .{},

quad_verts: Renderer.Handle = undefined,
quad_inds: Renderer.Handle = undefined,

pub fn init(app: *App) !void {
    _ = app;
    std.log.info("{s}: initialized", .{App.name});

    app.t.pos = .{ .x = 0, .y = 0, .z = 0 };
    app.t.scale = .{ .x = 10, .y = 10, .z = 0 };

    // allocate buffer and upload data
    std.log.debug("size of texcoords: {}", .{@sizeOf(@TypeOf(texcoords))});
    app.quad_verts = try Renderer.createBuffer(
        .{
            .size = @sizeOf(@TypeOf(texcoords)) + @sizeOf(@TypeOf(positions)),
            .usage = .Vertex,
        },
    );
    var offset = try Renderer.updateBuffer(app.quad_verts, 0, Vec3, positions[0..]);
    offset = try Renderer.updateBuffer(app.quad_verts, offset, Vec2, texcoords[0..]);

    app.quad_inds = try Renderer.createBuffer(
        .{
            .size = @sizeOf(@TypeOf(quad_inds)),
            .usage = .Index,
        },
    );
    _ = try Renderer.updateBuffer(app.quad_inds, 0, u32, quad_inds[0..]);
}

pub fn update(app: *App) !void {
    // app.t.rot = Quat.fromAxisAngle(Vec3.FORWARD, app.theta);
    app.theta += 0.033;
}

pub fn render(app: *App) !void {
    var cmd = Renderer.getCmdBuf();

    const rp_desc = .{
        .clear_color = .{ 0.0, 1.0, 0.0, 1.0 },
        .clear_depth = 1.0,
        .clear_stencil = 1.0,
        .clear_flags = .{
            .color = true,
            .depth = true,
        },
    };

    try cmd.beginRenderPass(rp_desc);

    try cmd.bindPipeline(.{});

    try cmd.drawIndexed(.{
        .count = 6,
        .vertex_handle = app.quad_verts,
        .index_handle = app.quad_inds,
    });

    try cmd.endRenderPass(rp_desc);

    try Renderer.submit(cmd);
}

pub fn deinit(app: *App) void {
    _ = app;
    std.log.info("{s}: deinitialized", .{App.name});
}
