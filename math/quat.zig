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
const Mat4 = @import("mat4.zig").Mat4;
const util = @import("util.zig");

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

    /// creates a new unit quaternion given an axis and angle
    /// axis does not have to be normalized as we do that here
    pub fn fromAngleAxis(vec: Vec3, angle: f32) Self {
        const sin = math.sin(angle / 2);
        const a = vec.norm().scale(sin);
        return Self.new(math.cos(angle / 2), a.x, a.y, a.z);
    }

    /// convinience function to create a quaternion from a vec3
    /// does not normalize
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
        var p = Self.fromVec3(v);
        p = q.mul(p).mul(q.inv());
        return Vec3.new(p.x, p.y, p.z);
    }

    pub fn toMat4(q: Self) Mat4 {
        var mat: Mat4 = undefined;
        const n = q.norm();
        const x = n.x;
        const y = n.y;
        const z = n.z;
        const w = n.w;

        const x2 = n.x * n.x;
        const y2 = n.y * n.y;
        const z2 = n.z * n.z;

        mat.m[0][0] = 1 - 2 * y2 - 2 * z2;
        mat.m[0][1] = 2 * (x * y) + 2 * (z * w);
        mat.m[0][2] = 2 * (x * z) - 2 * (y * w);
        mat.m[0][3] = 0;

        mat.m[1][0] = 2 * x * y - 2 * z * w;
        mat.m[1][1] = 1 - (2 * x2) - (2 * z2);
        mat.m[1][2] = 2 * (y * z) + 2 * (x * w);
        mat.m[1][3] = 0;

        mat.m[2][0] = 2 * (x * z) + 2 * (y * w);
        mat.m[2][1] = 2 * (y * z) - 2 * (x * w);
        mat.m[2][2] = 1 - (2 * x2) - (2 * y2);
        mat.m[2][3] = 0;

        mat.m[3][0] = 0;
        mat.m[3][1] = 0;
        mat.m[3][2] = 0;
        mat.m[3][3] = 1;

        return mat;
    }

    pub fn lerp(l: Self, r: Self, t: f32) Self {
        return Self.new(
            util.lerp(l.w, r.w, t),
            util.lerp(l.x, r.x, t),
            util.lerp(l.y, r.y, t),
            util.lerp(l.z, r.z, t),
        );
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

    const r2 = q.rotate(Vec3.new(2, 0, 0));
    try testing.expectApproxEqAbs(r2.x, 0, 0.001);
    try testing.expectApproxEqAbs(r2.y, 2, 0.001);
    try testing.expectApproxEqAbs(r2.z, 0, 0.001);
}

test "toMat4" {
    const q = Quat.fromAngleAxis(Vec3.new(1, 0, 0), math.pi);
    const rotx = q.toMat4().m;

    // from mat4 rotate test
    var rotx_expect: [4][4]f32 = .{
        .{ 1, 0, 0, 0 },
        .{ 0, -1, 0, 0 },
        .{ 0, 0, -1, 0 },
        .{ 0, 0, 0, 1 },
    };

    var row: usize = 0;
    while (row < 4) : (row += 1) {
        var col: usize = 0;
        while (col < 4) : (col += 1) {
            try testing.expectApproxEqAbs(rotx_expect[row][col], rotx[row][col], 0.001);
        }
    }
}

test "lerp" {
    const p = Quat{
        .w = 1,
        .x = 3,
        .y = -4,
        .z = -5,
    };

    const q = Quat{
        .w = 0,
        .x = 5,
        .y = 4,
        .z = 0,
    };

    const l = Quat.lerp(p, q, 0.5);

    try testing.expectApproxEqAbs(l.w, 0.5, 0.001);
    try testing.expectApproxEqAbs(l.x, 4.0, 0.001);
    try testing.expectApproxEqAbs(l.y, 0, 0.001);
    try testing.expectApproxEqAbs(l.z, -2.5, 0.001);
}
