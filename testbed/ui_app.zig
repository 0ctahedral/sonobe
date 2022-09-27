const std = @import("std");
const utils = @import("utils");
const log = utils.log.default;
const Handle = utils.Handle;
const Color = utils.Color;
const mesh = @import("mesh");
const quad = mesh.quad;

const UI = @import("ui.zig");

const device = @import("device");
const descs = device.resources.descs;
const render = @import("render");
const resources = @import("device").resources;
const platform = @import("platform");
const FontRen = @import("font").FontRen;
const CmdBuf = device.CmdBuf;

const math = @import("math");
const Vec4 = math.Vec4;
const Vec3 = math.Vec3;
const Vec2 = math.Vec2;
const Quat = math.Quat;
const Mat4 = math.Mat4;
const Transform = math.Transform;

const Camera = render.Camera;

const allocator = std.testing.allocator;
// since this file is implicitly a struct we can store state in here
// and use methods that we expect to be defined in the engine itself.
// we can then make our app a package which is included by the engine
const App = @This();

// color pallet namespace
const pallet = struct {
    pub const bg = Color.fromHex(0x190933);
    pub const bg_alt = Color.fromHex(0x40305D);

    pub const purple = Color.fromHex(0x665687);
    pub const active = Color.fromHex(0xB084CC);

    pub const fg = Color.fromHex(0xCDF3EE);
};

/// The name of this app (required)
pub const name = "testbed";

screen_pass: Handle(.RenderPass) = .{},

camera: Camera = .{
    .pos = .{ .y = -10, .z = 5 },
    .fov = 60,
},

last_pos: Vec2 = .{},

font_ren: FontRen = undefined,

ui: UI = .{},

button: UI.Id = 0,
button2: UI.Id = 0,

mode: u8 = 0,

const buttonStyle = .{
    .color = pallet.bg_alt.toLinear(),
    .hover_color = pallet.purple.toLinear(),
    .active_color = pallet.active.toLinear(),
};

pub fn init(app: *App) !void {
    // setup the camera
    try app.camera.init();
    app.camera.aspect = @intToFloat(f32, device.w) / @intToFloat(f32, device.h);

    // setup the material

    app.screen_pass = try resources.createRenderPass(.{
        .clear_color = pallet.bg.toLinear(),
        .clear_depth = 1.0,
        .clear_stencil = 1.0,
        .clear_flags = .{ .color = true, .depth = true },
    });

    app.font_ren = try FontRen.init("./assets/fonts/scientifica-11.bdf", app.screen_pass, allocator);
    // update the buffer with our projection
    _ = try resources.updateBufferTyped(app.font_ren.buffer, 0, Mat4, &[_]Mat4{
        Mat4.ortho(0, 800, 0, 600, -100, 100),
    });

    app.ui = try UI.init(app.screen_pass, allocator);
}

pub fn update(app: *App, dt: f64) !void {
    app.font_ren.clear();
    var buf: [80]u8 = undefined;
    _ = try app.font_ren.addString(
        try std.fmt.bufPrint(buf[0..], "dt: {d:.2} fps: {d:.2}", .{ dt * 1000.0, platform.fps() }),
        Vec2.new(0, 0),
        36,
        pallet.purple.toLinear(),
    );

    const rect = .{
        .x = @intToFloat(f32, device.w) - 110,
        .y = 10,
        .w = 100,
        .h = 50,
    };
    if (app.ui.button(&app.button, rect, buttonStyle)) {
        // app.mode = (app.mode + 1) % 4;
        // log.debug("{}", .{app.mode});
    }
    _ = app.ui.button(&app.button2, .{
        .y = 100,
        .w = 100,
        .h = 50,
    }, buttonStyle);

    var text: []const u8 = "click me";
    _ = try app.font_ren.addString(
        text,
        Vec2.new(rect.x + 5, rect.y + 5),
        16,
        pallet.fg.toLinear(),
    );

    try app.ui.update();
}

pub fn draw(app: *App) !void {
    var cmd = device.getCmdBuf();

    try cmd.beginRenderPass(app.screen_pass);

    try app.ui.draw(&cmd);

    try app.font_ren.drawGlyphsDebug(&cmd, @intToEnum(FontRen.GlyphDebugMode, app.mode));
    // try app.font_ren.drawAtlas(
    //     &cmd,
    //     @intToFloat(f32, device.w) - 400,
    //     @intToFloat(f32, device.h) - 400,
    //     400,
    //     400,
    // );

    try cmd.endRenderPass(app.screen_pass);

    try device.submit(cmd);
}

pub fn deinit(app: *App) void {
    app.ui.deinit();
    log.info("{s}: deinitialized", .{App.name});
}

pub fn onResize(app: *App, w: u16, h: u16) void {
    app.camera.aspect = @intToFloat(f32, w) / @intToFloat(f32, h);

    _ = resources.updateBufferTyped(app.font_ren.buffer, 0, Mat4, &[_]Mat4{
        Mat4.ortho(
            0,
            @intToFloat(f32, device.w),
            0,
            @intToFloat(f32, device.h),
            -100,
            100,
        ),
    }) catch unreachable;

    app.ui.onResize() catch unreachable;
}
