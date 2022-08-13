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
const Lines = @import("lines.zig");

/// The name of this app (required)
pub const name = "lines";
const allocator = std.testing.allocator;

/// renderpass for drawing to the screen
world_pass: renderer.Handle = .{},

screen_dim: Vec2 = .{ .x = 800, .y = 600 },

last_pos: Vec2 = .{},
camera: renderer.Camera = .{
    .pos = .{ .y = -10 },
    .fov = 60,
},

camera_move_speed: f32 = 5.0,
lines: Lines = undefined,

pub fn init(app: *App) !void {
    try app.camera.init();
    app.camera.aspect = @intToFloat(f32, renderer.w) / @intToFloat(f32, renderer.h);

    app.world_pass = try resources.createRenderPass(.{
        .clear_color = octal.color.hexToVec4(0x8af587ff),
        .clear_depth = 1.0,
        .clear_stencil = 1.0,
        .clear_flags = .{ .color = true, .depth = true },
    });

    app.lines = try Lines.init();
    const thickness = 0.2;
    const feather = 0.5;
    try app.lines.addLine(.{
        .start = .{},
        .end = .{ .x = 5 },
        .color = .{ .x = 1, .w = 1 },
        .thickness = thickness,
        .feather = feather,
    });
    try app.lines.addLine(.{
        .start = .{},
        .end = .{ .y = 5 },
        .color = .{ .y = 1, .w = 1 },
        .thickness = thickness,
        .feather = feather,
    });
    try app.lines.addLine(.{
        .start = .{},
        .end = .{ .z = 5 },
        .color = .{ .z = 1, .w = 1 },
        .thickness = thickness,
        .feather = feather,
    });

    var i: f32 = 1;
    var l = Lines.LineData{
        .start = .{},
        .end = .{ .z = 5 },
        .color = octal.color.hexToVec4(0xffffffff),
        .thickness = thickness / 2.0,
    };
    const segments = 20.0;
    const radius = 0.25;
    const frac = std.math.tau / segments;
    var last_pos = Vec3{ .x = radius, .z = 0 };
    while (i < segments + 1.0) : (i += 1) {
        var pos = Vec3{ .x = @cos(i * frac) * radius, .z = @sin(i * frac) * radius };
        l.start = last_pos;
        l.end = pos;
        try app.lines.addLine(l);
        last_pos = pos;
    }
}

pub fn update(app: *App, dt: f64) !void {
    // camera stuff
    var ivec = Vec3{};
    if (input.keyIs(.right, .down) or input.keyIs(.d, .down)) {
        ivec = ivec.add(app.camera.rot.rotate(Vec3.RIGHT));
    }
    if (input.keyIs(.left, .down) or input.keyIs(.a, .down)) {
        ivec = ivec.add(app.camera.rot.rotate(Vec3.LEFT));
    }
    if (input.keyIs(.up, .down) or input.keyIs(.w, .down)) {
        ivec = ivec.add(app.camera.rot.rotate(Vec3.FORWARD));
    }
    if (input.keyIs(.down, .down) or input.keyIs(.s, .down)) {
        ivec = ivec.add(app.camera.rot.rotate(Vec3.BACKWARD));
    }
    if (input.keyIs(.q, .down)) {
        ivec = ivec.add(Vec3.UP);
    }
    if (input.keyIs(.e, .down)) {
        ivec = ivec.add(Vec3.DOWN);
    }

    if (input.keyIs(.v, .press)) {
        app.camera.fov += 10;
        std.log.debug("fov changed to: {d:.2}", .{app.camera.fov});
    }
    if (input.keyIs(.c, .press)) {
        app.camera.fov -= 10;
        std.log.debug("fov changed to: {d:.2}", .{app.camera.fov});
    }

    const mag = ivec.len();
    if (mag > 0.0) {
        app.camera.pos = app.camera.pos.add(ivec.scale(app.camera_move_speed * @floatCast(f32, dt) / mag));
    }

    const left = input.getMouse().getButton(.left);
    if (left.action == .drag) {
        const ddrag = left.drag.sub(app.last_pos);
        app.camera.fpsRot(ddrag);
        app.last_pos = left.drag;
    } else {
        app.last_pos = .{};
    }
    try app.camera.update();
}

pub fn render(app: *App) !void {
    var cmd = renderer.getCmdBuf();

    try cmd.beginRenderPass(app.world_pass);

    try cmd.endRenderPass(app.world_pass);

    var vp = app.camera.view().mul(app.camera.proj());
    try app.lines.draw(&cmd, vp, app.camera.aspect);

    try renderer.submit(cmd);
}

pub fn deinit(app: *App) void {
    _ = app;
    std.log.info("{s}: deinitialized", .{App.name});
}

pub fn onResize(app: *App, w: u16, h: u16) void {
    app.camera.aspect = @intToFloat(f32, w) / @intToFloat(f32, h);
}
