//! Transforms!
//! Stores an models's world space and stuff for use in the model matrix

const std = @import("std");
const testing = std.testing;
const math = std.math;
const Vec3 = @import("vec3.zig").Vec3;
const Quat = @import("quat.zig").Quat;
const Mat4 = @import("mat4.zig").Mat4;
const util = @import("util.zig");

/// A Transform of a model
pub const Transform = struct {
    /// the position in world space
    pos: Vec3 = .{},
    /// the rotation in world space
    rot: Quat = .{},
    /// the scale in world space
    scale: Vec3 = Vec3.new(1, 1, 1),

    const Self = @This();

    /// get the local transformation matrix of the model
    pub inline fn mat(self: Self) Mat4 {
        // start with the rotation
        return self.rot.toMat4()
        // apply posiition
            .mul(Mat4.translate(self.pos))
        // apply scale
            .mul(Mat4.scale(self.scale));
    }

    pub fn translate(self: *Self, amt: Vec3) void {
        self.pos = self.pos.add(amt);
    }

    pub fn rotate(self: *Self, amt: Quat) void {
        self.rot = self.rot.mul(amt).mul(self.rot.inv());
    }

    pub fn xform(self: Self, v: Vec3) Vec3 {
        return v.matMul(self.mat());
    }
};

test "init" {
    var t = Transform{};

    try testing.expect(t.pos.eql(Vec3{}));
    try testing.expect(t.scale.eql(Vec3{ .x = 1, .y = 1, .z = 1 }));
    try testing.expect(t.rot.eql(Quat{}));
}

test "mat" {
    var t = Transform{};
    var l = t.mat();
    try testing.expect(l.eql(Mat4.identity()));
}
