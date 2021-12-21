//! Quaternions!
//! represents a rotation around an axis:
//! q = qv qs
//! q = a*sin(theta/2) cos(theta/2)
//! where a is the unit vector axis we rotate around
//! and theta is the angle amount we rotate around it.
//! the angle follows the right hand rule.

const std = @import("std");
const testing = std.testing;
const math = std.math;
const Vec3 = @import("vec3.zig").Vec3;

pub const Quat = struct {
    w: f32 = 1,
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,

    const Self = @This();

    /// convinience
    pub inline fn new(w: f32, x: f32, y: f32, z: f32) Self {
        return .{ .x = x, .y = y, .z = z, .w = w };
    }

    /// represents no rotation
    pub inline fn identity() Self {
        return Quat{};
    }

    pub fn norm(q: Self) Self {
        const d = math.sqrt(q.w * q.w + q.x * q.x + q.y * q.y + q.z * q.z);
        return Self.new(q.w / d, q.x / d, q.y / d, q.z / d);
    }

    /// creates a new quaternion given an axis and angle
    /// axis does not have to be normalized
    pub fn fromAngleAxis(vec: Vec3, angle: f32) Self {
        const a = vec.norm();
        const sin = math.sin(angle / 2);
        return Self.new(math.cos(angle / 2), a.x * sin, a.y * sin, a.z * sin);
    }

    pub inline fn fromVec3(v: Vec3) Self {
        return Self.new(0, v.x, v.y, v.z);
    }

    /// multiply two Quaternions
    /// grassman product
    /// creates composite rotation of q then p
    pub fn mul(l: Self, r: Self) Self {
        var ret: Self = undefined;

        ret.x = (l.x * r.w) + (l.y * r.z) - (l.z * r.y) + (l.w * r.x);
        ret.y = (-l.x * r.z) + (l.y * r.w) + (l.z * r.x) + (l.w * r.y);
        ret.z = (l.x * r.y) - (l.y * r.x) + (l.z * r.w) + (l.w * r.z);
        ret.w = (-l.x * r.x) - (l.y * r.y) - (l.z * r.z) + (l.w * r.w);

        return ret;
    }

    /// inverts a quaternion
    /// Assumes that the quaternion is normalized
    pub fn inv(q: Self) Self {
        const n = q.norm();
        return Self.new(n.w, -n.x, -n.y, -n.z);
    }

    /// rotates a vector by a quaternion
    pub fn rotate(q: Self, v: Vec3) Vec3 {
        // create quat from vec
        // TODO: normalize?
        var p = Self.fromVec3(v);
        p = q.mul(p).mul(q.inv());
        return Vec3.new(p.x, p.y, p.z);
    }
};

test "init" {
    const p = Quat{
        .w = 1,
        .x = 3,
        .y = 4,
        .z = 3,
    };

    const q = Quat.new(4, 3.9, -1, -3);

    try testing.expectEqual(p.w, 1);
    try testing.expectEqual(p.x, 3);
    try testing.expectEqual(p.y, 4);
    try testing.expectEqual(p.z, 3);

    try testing.expectEqual(q.w, 4);
    try testing.expectEqual(q.x, 3.9);
    try testing.expectEqual(q.y, -1);
    try testing.expectEqual(q.z, -3);

    var i = Quat.identity();
    try testing.expectEqual(i.w, 1);
    try testing.expectEqual(i.x, 0);
    try testing.expectEqual(i.y, 0);
    try testing.expectEqual(i.z, 0);
    i = Quat{};
    try testing.expectEqual(i.w, 1);
    try testing.expectEqual(i.x, 0);
    try testing.expectEqual(i.y, 0);
    try testing.expectEqual(i.z, 0);
}

test "multiply" {
    const p = Quat{
        .w = 1,
        .x = 3,
        .y = 4,
        .z = 3,
    };

    const q = Quat.new(4, 3.9, -1, -3);

    var n = p.mul(q);

    try testing.expectApproxEqAbs(n.w, 5.3, 0.001);
    try testing.expectApproxEqAbs(n.x, 6.9, 0.001);
    try testing.expectApproxEqAbs(n.y, 35.7, 0.001);
    try testing.expectApproxEqAbs(n.z, -9.6, 0.001);

    try testing.expectEqual(p.mul(Quat.identity()), p);
    try testing.expectEqual(q.mul(Quat.identity()), q);
}

test "norm" {
    const p = Quat{
        .w = 1,
        .x = 3,
        .y = -4,
        .z = -5,
    };

    const n = p.norm();

    try testing.expectApproxEqAbs(n.w, 0.140028, 0.001);
    try testing.expectApproxEqAbs(n.x, 0.42008, 0.001);
    try testing.expectApproxEqAbs(n.y, -0.560112, 0.001);
    try testing.expectApproxEqAbs(n.z, -0.70014, 0.001);
}

test "inv" {
    const p = Quat{
        .w = 1,
        .x = 3,
        .y = -4,
        .z = -5,
    };

    const i = p.inv();
    const n = p.norm();

    try testing.expectApproxEqAbs(i.w, n.w, 0.001);
    try testing.expectApproxEqAbs(i.x, -n.x, 0.001);
    try testing.expectApproxEqAbs(i.y, -n.y, 0.001);
    try testing.expectApproxEqAbs(i.z, -n.z, 0.001);
}

test "fromAngleAxis" {
    const q = Quat.fromAngleAxis(Vec3.new(0, 1, 0), math.pi);

    try testing.expectApproxEqAbs(q.w, 0, 0.001);
    try testing.expectApproxEqAbs(q.x, 0, 0.001);
    try testing.expectApproxEqAbs(q.y, 1, 0.001);
    try testing.expectApproxEqAbs(q.z, 0, 0.001);

    const p = Quat.fromAngleAxis(Vec3.new(0, 1, 1), math.pi / 3.0);
    try testing.expectApproxEqAbs(p.w, 0.8660, 0.001);
    try testing.expectApproxEqAbs(p.x, 0, 0.001);
    try testing.expectApproxEqAbs(p.y, 0.3535533, 0.001);
    try testing.expectApproxEqAbs(p.z, 0.3535533, 0.001);
}

test "rotate" {
    const q = Quat.fromAngleAxis(Vec3.new(0, 0, 1), math.pi / 2.0);
    const r = q.rotate(Vec3.new(1, 0, 0));
    try testing.expectApproxEqAbs(r.x, 0, 0.001);
    try testing.expectApproxEqAbs(r.y, 1, 0.001);
    try testing.expectApproxEqAbs(r.z, 0, 0.001);
}
