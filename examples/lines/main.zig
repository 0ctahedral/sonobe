const std = @import("std");
const sonobe = @import("sonobe");
const cube = sonobe.mesh.cube;
const quad = sonobe.mesh.quad;

const device = sonobe.device;
const resources = sonobe.device.resources;
const render = sonobe.render;
const input = sonobe.input;
const CmdBuf = device.CmdBuf;

const math = sonobe.math;
const Vec4 = math.Vec4;
const Vec3 = math.Vec3;
const Vec2 = math.Vec2;
const Quat = math.Quat;
const Mat4 = math.Mat4;
const Transform = math.Transform;
// since this file is implicitly a struct we can store state in here
// and use methods that we expect to be defined in the engine itself.
// we can then make our app a package which is included by the engine
const App = @This();
const Lines = @import("lines.zig");

/// The name of this app (required)
pub const name = "lines";
const allocator = std.testing.allocator;

/// renderpass for drawing to the screen
world_pass: sonobe.Handle(null) = .{},

screen_dim: Vec2 = .{ .x = 800, .y = 600 },

last_pos: Vec2 = .{},
camera: render.Camera = .{
    .pos = .{ .y = -10 },
    .fov = 60,
},

camera_move_speed: f32 = 5.0,
lines: Lines = undefined,

line_mode: u8 = 2,

pub fn init(app: *App) !void {
    try app.camera.init();
    app.camera.aspect = @intToFloat(f32, device.w) / @intToFloat(f32, device.h);

    app.world_pass = try resources.createRenderPass(.{
        .clear_color = sonobe.color.hexToVec4(0x8af587ff),
        .clear_depth = 1.0,
        .clear_stencil = 1.0,
        .clear_flags = .{ .color = true, .depth = true },
    });

    app.lines = try Lines.init();
    // const thickness = 0.2;
    const thickness = 4;
    //const feather = 0.5;
    try app.lines.addLine(.{
        .start = .{},
        .end = .{ .z = 1 },
        .color = .{ .z = 1, .w = 1 },
        .thickness = thickness,
    });

    try app.lines.addLine(.{
        .start = .{},
        .end = .{ .y = 1 },
        .color = .{ .y = 1, .w = 1 },
        .thickness = thickness,
    });

    try app.lines.addLine(.{
        .start = .{},
        .end = .{ .x = 1 },
        .color = .{ .x = 1, .w = 1 },
        .thickness = thickness,
        //.feather = feather,
    });
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

    if (input.keyIs(.space, .press)) {
        app.line_mode = (app.line_mode + 1) % 3;
        std.log.debug("line mode ({})", .{app.line_mode});
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

pub fn draw(app: *App) !void {
    var cmd = device.getCmdBuf();

    try cmd.beginRenderPass(app.world_pass);

    try cmd.endRenderPass(app.world_pass);

    //var vp = app.camera.view().mul(app.camera.proj());
    try app.lines.draw(&cmd, app.camera, @intToEnum(Lines.Type, app.line_mode));

    try device.submit(cmd);
}

pub fn deinit(app: *App) void {
    _ = app;
    std.log.info("{s}: deinitialized", .{App.name});
}

pub fn onResize(app: *App, w: u16, h: u16) void {
    app.camera.aspect = @intToFloat(f32, w) / @intToFloat(f32, h);
}
