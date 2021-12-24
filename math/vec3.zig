const std = @import("std");
const testing = std.testing;
const math = std.math;
const util = @import("util.zig");
// im being lazy so this will all be in f32 and can be changed later

pub const Vec3 = struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,

    const Self = @This();

    /// convinience function to create a new Vec without struct syntax
    pub inline fn new(x: f32, y: f32, z: f32) Self {
        return .{ .x = x, .y = y, .z = z };
    }

    /// add two vectors
    pub fn add(v: Self, o: Self) Self {
        return .{ .x = v.x + o.x, .y = v.y + o.y, .z = v.z + o.z };
    }

    /// subtract two vectors
    pub fn sub(v: Self, o: Self) Self {
        return .{ .x = v.x - o.x, .y = v.y - o.y, .z = v.z - o.z };
    }

    /// multiply a vector by a scalar
    pub fn scale(v: Self, s: f32) Self {
        return .{ .x = s * v.x, .y = s * v.y, .z = s * v.z };
    }

    /// multiply a vector by a vector component-wise
    pub fn mul(v: Self, o: Self) Self {
        return .{ .x = v.x * o.x, .y = v.y * o.y, .z = v.z * o.z };
    }

    /// the magnitude of a vector
    pub fn len(v: Self) f32 {
        return math.sqrt((v.x * v.x) + (v.y * v.y) + (v.z * v.z));
    }

    /// normalize the vector
    pub fn norm(v: Self) Self {
        const l = v.len();
        return .{ .x = v.x / l, .y = v.y / l, .z = v.z / l };
    }

    /// dot product
    pub fn dot(v: Self, o: Self) f32 {
        return v.x * o.x + v.y * o.y + v.z * o.z;
    }

    /// cross product
    pub fn cross(v: Self, o: Self) Self {
        return .{
            .x = v.y * o.z - v.z * o.y,
            .y = v.z * o.x - v.x * o.z,
            .z = v.x * o.y - v.y * o.x,
        };
    }

    /// the distance between two vectors
    pub fn dist(v: Self, o: Self) f32 {
        return math.sqrt((v.x - o.x) * (v.x - o.x) +
            (v.y - o.y) * (v.y - o.y) +
            (v.z - o.z) * (v.z - o.z));
    }

    /// lerp
    pub fn lerp(l: Self, r: Self, t: f32) Self {
        return Self.new(
            util.lerp(l.x, r.x, t),
            util.lerp(l.y, r.y, t),
            util.lerp(l.z, r.z, t),
        );
    }
};

test "new" {
    // normal new
    var v = Vec3{ .x = 0.0, .y = 1.5, .z = 0 };
    var v1 = Vec3.new(-0.8, 1.5, 2);

    try testing.expectEqual(v.x, 0);
    try testing.expectEqual(v.y, 1.5);
    try testing.expectEqual(v.z, 0);
    try testing.expectEqual(v1.x, -0.8);
    try testing.expectEqual(v1.y, 1.5);
    try testing.expectEqual(v1.z, 2);
}

test "add/sub" {
    var v = Vec3{ .x = 0.0, .y = 1.5, .z = 1 };
    var v1 = Vec3.new(-0.8, 1.5, 2);

    try testing.expectEqual(v.sub(v1), Vec3.new(0.8, 0, -1));
    try testing.expectEqual(v.add(v1), Vec3.new(-0.8, 3, 3));
}

test "scale/mul" {
    var v = Vec3{ .x = -0.5, .y = 1.5, .z = 1 };
    v = v.scale(1);
    try testing.expectEqual(v.x, -0.5);
    try testing.expectEqual(v.y, 1.5);
    try testing.expectEqual(v.z, 1);
    var v1 = v.scale(2);
    try testing.expectEqual(v1.x, -1);
    try testing.expectEqual(v1.y, 3);
    try testing.expectEqual(v1.z, 2);

    var v2 = v1.mul(v);
    try testing.expectEqual(v2.x, 0.5);
    try testing.expectEqual(v2.y, 4.5);
    try testing.expectEqual(v2.z, 2);
}

test "len" {
    var v = Vec3.new(-0.8, 1.5, 5);
    try testing.expectApproxEqAbs(v.len(), 5.28109, 0.001);
}

test "norm" {
    var v = Vec3.new(-0.8, 1.5, 5);
    var n = v.norm();
    try testing.expectApproxEqAbs(n.x, -0.15148, 0.001);
    try testing.expectApproxEqAbs(n.y, 0.28403, 0.001);
    try testing.expectApproxEqAbs(n.z, 0.94677, 0.001);
    v = Vec3.new(1, 0, 0);
    try testing.expectEqual(v.norm(), v);
}

test "dot" {
    var a = Vec3.new(1, 2, 3);
    var b = Vec3.new(1, 5, 7);
    try testing.expectApproxEqAbs(a.dot(b), 32, 0.001);
    try testing.expectApproxEqAbs(b.dot(a), 32, 0.001);
}

test "cross" {
    var a = Vec3.new(1, 2, 3);
    var b = Vec3.new(1, 5, 7);
    try testing.expectEqual(a.cross(b), Vec3.new(-1, -4, 3));
}

test "dist" {
    var a = Vec3.new(1, 2, 3);
    var b = Vec3.new(1, 5, 7);
    try testing.expectEqual(a.dist(b), 5);
    try testing.expectEqual(b.dist(a), 5);
}

test "lerp" {
    var a = Vec3.new(1, 2, -10);
    var b = Vec3.new(-1, 5, -5);
    var c = Vec3.lerp(a, b, 0.5);
    try testing.expectApproxEqAbs(c.x, 0.0, 0.001);
    try testing.expectApproxEqAbs(c.y, 3.5, 0.001);
    try testing.expectApproxEqAbs(c.z, -7.5, 0.001);
}
