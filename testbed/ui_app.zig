const std = @import("std");
const utils = @import("utils");
const log = utils.log.default;
const Handle = utils.Handle;
const Color = utils.Color;
const mesh = @import("mesh");
const quad = mesh.quad;

const UI = @import("ui.zig");
const Rect = UI.Rect;

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

ui: UI = .{},

button: UI.Id = 0,
button2: UI.Id = 0,

// dimesnsions of the device
dims: Vec2 = Vec2.new(800, 600),

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

    app.ui = try UI.init(app.screen_pass, allocator);
}

pub fn update(app: *App, dt: f64) !void {
    // fps text
    var buf: [80]u8 = undefined;
    const str = try std.fmt.bufPrint(
        buf[0..],
        "dt: {d:.2} fps: {d:.2}",
        .{
            dt * 1000.0,
            platform.fps(),
        },
    );
    app.ui.text(
        str,
        Vec2.new(0, 0),
        18,
        pallet.active.toLinear(),
    );

    // buttons
    {
        const rect = .{
            .x = @intToFloat(f32, device.w) - 110,
            .y = 10,
            .w = 100,
            .h = 50,
        };
        if (app.ui.button(&app.button, rect, buttonStyle)) {
            log.debug("clicked", .{});
        }
        var text: []const u8 = "click me";
        app.ui.text(
            text,
            Vec2.new(rect.x + 5, rect.y + 5),
            16,
            pallet.active.toLinear(),
        );
    }

    // lil window in the middle
    {
        const rect = Rect{
            .x = 30,
            .y = 70,
            .w = app.dims.x - 60,
            .h = app.dims.y - 100,
        };
        // border
        app.ui.addRect(
            .solid,
            rect,
            pallet.active.toLinear(),
        );
        // bg
        app.ui.addRect(
            .solid,
            rect.shrink(10),
            pallet.bg_alt.toLinear(),
        );
    }
}

pub fn draw(app: *App) !void {
    var cmd = device.getCmdBuf();

    try cmd.beginRenderPass(app.screen_pass);

    try app.ui.draw(&cmd);

    try cmd.endRenderPass(app.screen_pass);

    try device.submit(cmd);
}

pub fn deinit(app: *App) void {
    app.ui.deinit();
    log.info("{s}: deinitialized", .{App.name});
}

pub fn onResize(app: *App, w: u16, h: u16) void {
    app.dims = Vec2.new(@intToFloat(f32, w), @intToFloat(f32, h));
    app.camera.aspect = app.dims.x / app.dims.y;
    app.ui.onResize() catch unreachable;
}
