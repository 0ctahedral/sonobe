const std = @import("std");
const octal = @import("octal");
const cube = octal.mesh.cube;
const quad = octal.mesh.quad;

const renderer = octal.renderer;
const resources = octal.renderer.resources;
const input = octal.input;
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
pub const name = "lines";

/// renderpass for drawing to the screen
screen_pass: renderer.Handle = .{},

screen_dim: Vec2 = .{ .x = 800, .y = 600 },

const allocator = std.testing.allocator;

const MAX_LINES = 1024;

pub fn init(app: *App) !void {
    app.screen_pass = try resources.createRenderPass(.{
        .clear_color = .{ 0.75, 0.49, 0.89, 1.0 },
        .clear_depth = 1.0,
        .clear_stencil = 1.0,
        .clear_flags = .{ .depth = true, .color = true },
    });


    app.inds = try resources.createBuffer(
        .{
            .size = MAX_LINES * 6 * @sizeOf(u32),
            .usage = .Index,
        },
    );

    self.group = try resources.createBindingGroup(&.{
        .{ .binding_type = .StorageBuffer },
        .{ .binding_type = .Texture },
        .{ .binding_type = .Sampler },
    });

    self.buffer = try resources.createBuffer(
        .{
            .size = @sizeOf(Mat4) + (2 * @sizeOf(Vec2)) + MAX_GLYPHS * @sizeOf(GlyphData),
            .usage = .Storage,
        },
    );
    _ = try renderer.updateBuffer(
        self.buffer,
        @sizeOf(Mat4),
        Vec2,
        &[_]Vec2{
            Vec2.new(
                @intToFloat(f32, self.atlas_dimension),
                @intToFloat(f32, self.atlas_dimension),
            ),
            Vec2.new(
                @intToFloat(f32, self.bdf.header.bb.x),
                @intToFloat(f32, self.bdf.header.bb.y),
            ),
        },
    );
}

pub fn update(_: *App, _: f64) !void {}

pub fn render(app: *App) !void {
    var cmd = renderer.getCmdBuf();

    try cmd.beginRenderPass(app.screen_pass);

    try cmd.endRenderPass(app.screen_pass);

    try renderer.submit(cmd);
}

pub fn deinit(app: *App) void {
    _ = app;
    std.log.info("{s}: deinitialized", .{App.name});
}

pub fn onResize(app: *App, w: u16, h: u16) void {
    app.screen_dim.x = @intToFloat(f32, w);
    app.screen_dim.y = @intToFloat(f32, h);
}
