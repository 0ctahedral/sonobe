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
const FontRen = @import("fontren.zig");
// since this file is implicitly a struct we can store state in here
// and use methods that we expect to be defined in the engine itself.
// we can then make our app a package which is included by the engine
const App = @This();

/// The name of this app (required)
pub const name = "font";

/// renderpass for drawing to the screen
screen_pass: renderer.Handle = .{},

screen_dim: Vec2 = .{ .x = 800, .y = 600 },

font_ren: FontRen = undefined,

should_draw_atlas: bool = true,

glyph_debug_mode: FontRen.GlyphDebugMode = .normal,

const allocator = std.testing.allocator;

pub fn init(app: *App) !void {
    app.screen_pass = try resources.createRenderPass(.{
        .clear_color = .{ 0.75, 0.49, 0.89, 1.0 },
        .clear_depth = 1.0,
        .clear_stencil = 1.0,
        .clear_flags = .{ .depth = true, .color = true },
    });

    app.font_ren = try FontRen.init("./assets/scientifica-11.bdf", app.screen_pass, allocator);
    // update the buffer with our projection
    _ = try renderer.updateBuffer(app.font_ren.buffer, 0, Mat4, &[_]Mat4{
        Mat4.ortho(0, app.screen_dim.x, 0, app.screen_dim.y, -100, 100),
    });

    // render some shit
    app.font_ren.clear();
    try app.font_ren.addGlyph(@as(u32, '$'), Vec2.new(20, 20), 20);
    try app.font_ren.addGlyph(@as(u32, 'm'), Vec2.new(30, 20), 20);
    try app.font_ren.addGlyph(@as(u32, 'o'), Vec2.new(40, 20), 20);
    try app.font_ren.addGlyph(@as(u32, 'r'), Vec2.new(50, 20), 20);
    try app.font_ren.addGlyph(@as(u32, 'g'), Vec2.new(60, 20), 20);
    try app.font_ren.addGlyph(@as(u32, 'a'), Vec2.new(70, 20), 20);
    try app.font_ren.addGlyph(@as(u32, 'n'), Vec2.new(80, 20), 20);
}

pub fn update(app: *App, _: f64) !void {
    if (input.keyIs(.space, .press)) {
        app.should_draw_atlas = !app.should_draw_atlas;
        std.log.info("toggle draw atlas", .{});
    }

    if (input.keyIs(.n, .press))
        app.glyph_debug_mode = .normal;
    if (input.keyIs(.m, .press))
        app.glyph_debug_mode = .solid;
    if (input.keyIs(.o, .press))
        app.glyph_debug_mode = .outlined;
}

pub fn render(app: *App) !void {
    var cmd = renderer.getCmdBuf();

    try cmd.beginRenderPass(app.screen_pass);

    try app.font_ren.drawGlyphsDebug(&cmd, app.glyph_debug_mode);

    if (app.should_draw_atlas) {
        try app.font_ren.drawAtlas(
            &cmd,
            app.screen_dim.x - 240,
            app.screen_dim.y - 240,
            240,
            240,
        );
    }

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

    //// update the buffer with our projection
    _ = renderer.updateBuffer(app.font_ren.buffer, 0, Mat4, &[_]Mat4{
        Mat4.ortho(0, app.screen_dim.x, 0, app.screen_dim.y, -100, 100),
    }) catch {
        std.log.warn("cound not update uniform buffer", .{});
    };
}
