const std = @import("std");
const octal = @import("octal");

const mmath = octal.mmath;
const Vec3 = mmath.Vec3;
const Quat = mmath.Quat;
const Transform = mmath.Transform;

// since this file is implicitly a struct we can store state in here
// and use methods that we expect to be defined in the engine itself.
// we can then make our app a package which is included by the engine
const App = @This();

/// The name of this app (required)
pub const name = "testbed";

// internal state of the app
/// angle that we have rotated the quad to
theta: f32 = 0,
/// transform of the quad
t: Transform = .{},

pub fn init(app: *App) !void {
    _ = app;
    std.log.info("{s}: initialized", .{App.name});

    app.t.pos = .{ .x = 0, .y = 0, .z = 0 };
    app.t.scale = .{ .x = 10, .y = 10, .z = 0 };
}

pub fn update(app: *App) !void {
    // app.t.rot = Quat.fromAxisAngle(Vec3.FORWARD, app.theta);
    octal.Renderer.push_constant.model = app.t.mat();
    app.theta += 0.033;
}

pub fn deinit(app: *App) void {
    _ = app;
    std.log.info("{s}: deinitialized", .{App.name});
}
