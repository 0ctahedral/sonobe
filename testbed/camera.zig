const std = @import("std");
const octal = @import("octal");
const cube = @import("cube.zig");
const Renderer = octal.Renderer;
const Resources = Renderer.Resources;

const Handle = Renderer.Handle;
const CmdBuf = Renderer.CmdBuf;
const mmath = octal.mmath;
const Mat4 = mmath.Mat4;
const Vec3 = mmath.Vec3;
const Vec2 = mmath.Vec2;
const Quat = mmath.Quat;

const Self = @This();
// camera settings
pub const Data = struct {
    proj: Mat4,
    view: Mat4,
};

pos: Vec3 = .{},
rot: Quat = .{},
near: f32 = 0.1,
far: f32 = 1000,

// horizontal fov in degrees
fov: f32 = 85,
aspect: f32 = 800.0 / 600.0,

drag_scale: f32 = (-1 / 400.0),

group: Handle = .{},
/// the buffer with data about this camera
buffer: Handle = .{},

pub fn init(self: *Self) !void {
    self.group = try Resources.createBindingGroup(&.{
        .{ .binding_type = .Buffer },
    });
    self.buffer = try Resources.createBuffer(.{
        .size = @sizeOf(Data),
        .usage = .Uniform,
    });
    try Resources.updateBindings(self.group, &[_]Resources.BindingUpdate{
        .{ .binding = 0, .handle = self.buffer },
    });
}

/// updates the gpu buffer of camera info
pub fn update(self: Self) !void {
    _ = try Renderer.updateBuffer(self.buffer, 0, Data, &[_]Data{.{
        .view = self.view(),
        .proj = self.proj(),
    }});
}
/// compute the view matrix for the camera
pub fn view(self: Self) Mat4 {
    var ret = self.rot.toMat4();
    return ret.mul(Mat4.translate(self.pos)).inv();
}

/// projection matrix for this camera
pub fn proj(self: Self) Mat4 {
    const half_hor_fov = std.math.tan(mmath.util.rad(self.fov) * 0.5);
    const y_fov = std.math.atan(half_hor_fov / self.aspect) * 2.0;
    return Mat4.perspective(y_fov, self.aspect, self.near, self.far);
}

/// change the camera rotation based on a pitch and yaw vector
/// basically a fps camera
pub fn fpsRot(self: *Self, drag: Vec2) void {
    const amt = drag.scale(self.drag_scale);
    const yaw = Quat.fromAxisAngle(Vec3.UP, amt.x);
    const pitch = Quat.fromAxisAngle(Vec3.RIGHT, amt.y);
    var new_rot = self.rot.mul(pitch);
    new_rot = yaw.mul(new_rot);
    self.rot = new_rot;
}

/// change the rotation and direction of the camera with an orbit
pub fn orbit(self: *Self, target: Vec3, amt: Vec2) void {
    const dir = self.pos.sub(target);
    var rotated_dir = Quat.fromAxisAngle(Vec3.UP, amt.x).rotate(dir);
    self.pos = self.pos.add(rotated_dir.sub(dir));
    self.rot = self.rot.mul(Quat.lookAt(target, self.rot.rotate(Vec3.FORWARD), self.pos, Vec3.UP));
}
