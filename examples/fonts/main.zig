const std = @import("std");
const octal = @import("octal");
const cube = octal.mesh.cube;
const quad = octal.mesh.quad;

const renderer = octal.renderer;
const resources = octal.renderer.resources;
const input = octal.input;
const CmdBuf = renderer.CmdBuf;

const math = octal.math;
const Vec4 = math.Vec4;
const Vec3 = math.Vec3;
const Vec2 = math.Vec2;
const Quat = math.Quat;
const Mat4 = math.Mat4;
const Transform = math.Transform;
const FontRen = octal.font.FontRen;
// since this file is implicitly a struct we can store state in here
// and use methods that we expect to be defined in the engine itself.
// we can then make our app a package which is included by the engine
const App = @This();

/// The name of this app (required)
pub const name = "font";

/// renderpass for drawing to the screen
screen_pass: octal.Handle(null) = .{},

screen_dim: Vec2 = .{ .x = 800, .y = 600 },

font_ren: FontRen = undefined,

should_draw_atlas: bool = true,

glyph_debug_mode: FontRen.GlyphDebugMode = .normal,

const allocator = std.testing.allocator;

pub fn init(app: *App) !void {
    app.screen_pass = try resources.createRenderPass(.{
        .clear_color = Vec4.new(0.75, 0.49, 0.89, 1.0),
        .clear_depth = 1.0,
        .clear_stencil = 1.0,
        .clear_flags = .{ .depth = true, .color = true },
    });

    app.font_ren = try FontRen.init("./assets/fonts/scientifica-11.bdf", app.screen_pass, allocator);
    // update the buffer with our projection
    _ = try renderer.updateBuffer(app.font_ren.buffer, 0, Mat4, &[_]Mat4{
        Mat4.ortho(0, app.screen_dim.x, 0, app.screen_dim.y, -100, 100),
    });

    // render some shit
    app.font_ren.clear();
    _ = try app.font_ren.addString(
        "$hello world!",
        Vec2.new(20, 20),
        20,
        octal.color.hexToVec4(0x181bc7ff),
    );
    var pos = Vec2.new(100, 50);
    pos.y += (try app.font_ren.addString(
        "A B C D E F G H I J K L M N O P Q R S T U V W X Y Z",
        pos,
        20,
        octal.color.hexToVec4(0x181bc7ff),
    )).y;
    pos.y += (try app.font_ren.addString(
        "a b c d e f g h i j k l m n o p q r s t u v w x y z",
        pos,
        20,
        octal.color.hexToVec4(0xffffffff),
    )).y;
    pos.x = 150;
    pos.y += (try app.font_ren.addString(
        "1 2 3 4 5 6 7 8 9 0",
        pos,
        20,
        octal.color.hexToVec4(0xe89c31ff),
    )).y;
    pos.x = 90;
    pos.y += (try app.font_ren.addString(
        "() [] {} <> ? / \\ : \" ' ; ! @ # $ % & * + - = - | ~ `",
        pos,
        20,
        octal.color.hexToVec4(0x145411ff),
    )).y;

    _ = try app.font_ren.addString(
        "try app.font_ren = @sizeOf(UrMom)",
        Vec2.new(100, 300),
        24,
        octal.color.hexToVec4(0x1b0cebff),
    );

    _ = try app.font_ren.addString(
        "|this is|text|",
        Vec2.new(100, 500),
        50,
        octal.color.hexToVec4(0x145411ff),
    );
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
    if (input.keyIs(.u, .press))
        app.glyph_debug_mode = .uv;
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
