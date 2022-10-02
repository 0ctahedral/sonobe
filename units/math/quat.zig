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

pub const Quat = packed struct {
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

    pub inline fn eql(l: Self, r: Self) bool {
        return (l.w == r.w and l.x == r.x and l.y == r.y and l.z == r.z);
    }

    pub inline fn add(l: Self, r: Self) Self {
        return Self.new(
            l.w + r.w,
            l.x + r.x,
            l.y + r.y,
            l.z + r.z,
        );
    }

    /// multiply a quaternion by a scalar
    pub inline fn scale(q: Self, s: f32) Self {
        return Self.new(
            q.w * s,
            q.x * s,
            q.y * s,
            q.z * s,
        );
    }

    pub inline fn norm(q: Self) Self {
        const d = math.sqrt(q.w * q.w + q.x * q.x + q.y * q.y + q.z * q.z);
        return Self.new(q.w / d, q.x / d, q.y / d, q.z / d);
    }

    /// creates a new unit quaternion given an axis and angle
    /// axis does not have to be normalized as we do that here
    pub inline fn fromAxisAngle(axis: Vec3, angle: f32) Self {
        const sin = math.sin(angle / 2);
        const a = axis.norm().scale(sin);
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
    pub inline fn mul(l: Self, r: Self) Self {
        var ret: Self = undefined;

        ret.x = (l.x * r.w) + (l.y * r.z) - (l.z * r.y) + (l.w * r.x);
        ret.y = (-l.x * r.z) + (l.y * r.w) + (l.z * r.x) + (l.w * r.y);
        ret.z = (l.x * r.y) - (l.y * r.x) + (l.z * r.w) + (l.w * r.z);
        ret.w = (-l.x * r.x) - (l.y * r.y) - (l.z * r.z) + (l.w * r.w);

        return ret;
    }

    /// inverts a quaternion
    /// Assumes that the quaternion is normalized
    /// and thus just uses the conjugate
    pub inline fn inv(q: Self) Self {
        const n = q.norm();
        return Self.new(n.w, -n.x, -n.y, -n.z);
    }

    pub inline fn toMat4(q: Self) Mat4 {
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

    // TODO: basis type?
    /// assumes that this is a pure rotation matrix
    pub inline fn fromMat4(mat: Mat4) Self {
        const trace = mat.m[0][0] + mat.m[1][1] + mat.m[2][2];

        var q = Self{};

        // check diagonal
        if (trace > 0.0) {
            const s = @sqrt(trace + 1.0);
            q.w = s * 0.5;

            const t = 0.5 / s;
            q.x = (mat.m[2][1] - mat.m[1][2]) * t;
            q.y = (mat.m[0][2] - mat.m[2][0]) * t;
            q.z = (mat.m[1][0] - mat.m[0][1]) * t;
        } else {
            var i: usize = 0;
            if (mat.m[1][1] > mat.m[0][0]) i = 1;
            if (mat.m[2][2] > mat.m[i][i]) i = 2;

            const next = [_]usize{ 1, 2, 0 };
            var vals = [_]f32{ 0, 0, 0, 0 };

            const j = next[i];
            const k = next[j];

            const s = @sqrt((mat.m[i][i] - (mat.m[j][j] + mat.m[k][k])) + 1.0);

            var t: f32 = if (s != 0.0) (0.5 / s) else s;

            vals[i] = s * 0.5;

            q.w = (mat.m[k][j] - mat.m[j][k]) * t;
            vals[j] = (mat.m[j][i] + mat.m[i][j]) * t;
            vals[k] = (mat.m[k][i] + mat.m[i][k]) * t;

            q.x = vals[0];
            q.y = vals[1];
            q.z = vals[2];
        }

        return q;
    }

    /// linerar interpolation between two Quaternions
    /// returns a normalized output since the calculation does not
    /// preserve length
    pub inline fn lerp(l: Self, r: Self, t: f32) Self {
        return Self.new(
            util.lerp(f32, l.w, r.w, t),
            util.lerp(f32, l.x, r.x, t),
            util.lerp(f32, l.y, r.y, t),
            util.lerp(f32, l.z, r.z, t),
        ).norm();
    }

    /// spherical linear interpolation between two Quaternions
    /// assumes that both have been normalized
    pub inline fn slerp(l: Self, r: Self, t: f32) Self {
        var ret: Self = Self.identity();
        // dot product of the two
        // TODO: should this be its own fuction?
        var dot = l.x * r.x + l.y * r.y + l.z * r.z + l.w * r.w;
        if (dot < 0.0) {
            dot *= -1.0;
        }
        const theta = math.acos(dot);

        ret = l.scale(math.sin((1 - t) * theta))
            .add(r.scale(math.sin(t * theta)))
            .scale(math.sin(theta));

        return ret;
    }

    /// rotates a vector by a quaternion
    pub inline fn rotate(q: Self, v: Vec3) Vec3 {
        // create quat from vec
        var p = Self.fromVec3(v);
        p = q.mul(p).mul(q.inv());
        return Vec3.new(p.x, p.y, p.z);
    }

    /// creates a quaterion rotation toward the specified point 
    /// expects dir to be normalized
    pub fn lookAt(dir: Vec3, up: Vec3) Self {
        // _ = up;
        // // const rot_axis = Vec3.FORWARD.cross(dir).norm();
        // const rot_axis = up;
        // // TODO: if the length is zero (aka parallel)
        // // create angle around rotation axis
        // const dot = Vec3.FORWARD.dot(dir);
        // const theta = std.math.acos(dot);
        // // TODO: is the trig function worth it?
        // return Self.fromAxisAngle(rot_axis, theta);

        var m = Mat4.identity();

        const ndir = Vec3.new(-dir.x, -dir.y, -dir.z);

        m.m[2][0] = ndir.x;
        m.m[2][1] = ndir.y;
        m.m[2][2] = ndir.z;

        var right = up.cross(ndir);
        right = right.scale(1.0 / @sqrt(std.math.max(0.00001, right.dot(right))));

        m.m[0][0] = right.x;
        m.m[0][1] = right.y;
        m.m[0][2] = right.z;

        const new_up = ndir.cross(right);

        m.m[1][0] = new_up.x;
        m.m[1][1] = new_up.y;
        m.m[1][2] = new_up.z;

        return Quat.fromMat4(m);
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

test "fromAxisAngle" {
    const q = Quat.fromAxisAngle(Vec3.new(0, 1, 0), math.pi);

    try testing.expectApproxEqAbs(q.w, 0, 0.001);
    try testing.expectApproxEqAbs(q.x, 0, 0.001);
    try testing.expectApproxEqAbs(q.y, 1, 0.001);
    try testing.expectApproxEqAbs(q.z, 0, 0.001);

    const p = Quat.fromAxisAngle(Vec3.new(0, 1, 1), math.pi / 3.0);
    try testing.expectApproxEqAbs(p.w, 0.8660, 0.001);
    try testing.expectApproxEqAbs(p.x, 0, 0.001);
    try testing.expectApproxEqAbs(p.y, 0.3535533, 0.001);
    try testing.expectApproxEqAbs(p.z, 0.3535533, 0.001);

    const v = Quat.fromAxisAngle(Vec3.new(1, 0, 0), math.pi / 2.0);
    try testing.expectApproxEqAbs(v.w, 0.7071, 0.001);
    try testing.expectApproxEqAbs(v.x, 0.7071, 0.001);
    try testing.expectApproxEqAbs(v.y, 0.0, 0.001);
    try testing.expectApproxEqAbs(v.z, 0.0, 0.001);
}

test "rotate" {
    const q = Quat.fromAxisAngle(Vec3.new(0, 0, 1), math.pi / 2.0);
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
    const q = Quat{};
    const norot = q.toMat4().m;
    const q1 = Quat.fromAxisAngle(Vec3.new(1, 0, 0), math.pi);
    const rotx = q1.toMat4().m;

    // from mat4 rotate test
    var rotx_expect: [4][4]f32 = .{
        .{ 1, 0, 0, 0 },
        .{ 0, -1, 0, 0 },
        .{ 0, 0, -1, 0 },
        .{ 0, 0, 0, 1 },
    };

    var norot_expect: [4][4]f32 = .{
        .{ 1, 0, 0, 0 },
        .{ 0, 1, 0, 0 },
        .{ 0, 0, 1, 0 },
        .{ 0, 0, 0, 1 },
    };

    var row: usize = 0;
    while (row < 4) : (row += 1) {
        var col: usize = 0;
        while (col < 4) : (col += 1) {
            try testing.expectApproxEqAbs(rotx_expect[row][col], rotx[row][col], 0.001);
            try testing.expectApproxEqAbs(norot_expect[row][col], norot[row][col], 0.001);
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

    const l = Quat.lerp(f32, p, q, 0.5);
    // normalized
    try testing.expectApproxEqAbs(l.w, 0.105409, 0.001);
    try testing.expectApproxEqAbs(l.x, 0.843274, 0.001);
    try testing.expectApproxEqAbs(l.y, 0, 0.001);
    try testing.expectApproxEqAbs(l.z, -0.527046, 0.001);
}

test "slerp" {
    const eps_value = comptime std.math.epsilon(f32);
    // 0 degrees on x axis
    const a = Quat.fromAxisAngle(Vec3.new(1, 0, 0), 0);
    // 180 degrees on x axis
    const b = Quat.fromAxisAngle(Vec3.new(1, 0, 0), math.pi);
    // 90 degrees on x axis
    const c = Quat.fromAxisAngle(Vec3.new(1, 0, 0), math.pi / 2.0);

    var s = Quat.slerp(f32, a, b, 1.0);
    try testing.expectApproxEqAbs(s.w, b.w, eps_value);
    try testing.expectApproxEqAbs(s.x, b.x, eps_value);
    try testing.expectApproxEqAbs(s.y, b.y, eps_value);
    try testing.expectApproxEqAbs(s.z, b.z, eps_value);

    const v = Quat.slerp(f32, a, b, 0.50);
    try testing.expectApproxEqAbs(v.w, c.w, eps_value);
    try testing.expectApproxEqAbs(v.x, c.x, eps_value);
    try testing.expectApproxEqAbs(v.y, c.y, eps_value);
    try testing.expectApproxEqAbs(v.z, c.z, eps_value);
}

test "eql" {
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

    try testing.expect(p.eql(p));
    try testing.expect(q.eql(q));
    try testing.expect(!q.eql(p));
    try testing.expect(!p.eql(q));
}

//test "fromMat4" {
//    const eps_value = comptime std.math.epsilon(f32);
//
//    var q = Quat.fromAxisAngle(Vec3.new(1, 0, 0), math.pi);
//    // var p = Quat.fromMat4(q.toMat4());
//
//    // try testing.expectApproxEqAbs(p.w, q.w, eps_value);
//    // try testing.expectApproxEqAbs(p.x, q.x, eps_value);
//    // try testing.expectApproxEqAbs(p.y, q.y, eps_value);
//    // try testing.expectApproxEqAbs(p.z, q.z, eps_value);
//
//    q = Quat.fromAxisAngle(Vec3.RIGHT, math.pi / 2.0).mul(q);
//    var p = Quat.fromMat4(q.toMat4());
//
//    try testing.expectApproxEqAbs(q.w, p.w, eps_value);
//    try testing.expectApproxEqAbs(q.x, p.x, eps_value);
//    try testing.expectApproxEqAbs(q.y, p.y, eps_value);
//    try testing.expectApproxEqAbs(q.z, p.z, eps_value);
//}
