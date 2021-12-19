const std = @import("std");
const testing = std.testing;
const math = std.math;
// im being lazy so this will all be in f32 and can be changed later

pub const Vec2 = struct {
    x: f32,
    y: f32,

    const Self = @This();

    /// convinience function to create a new Vec without struct syntax
    pub inline fn new(x: f32, y: f32) Self {
        return .{ .x = x, .y = y };
    }

    /// add two vectors
    pub fn add(v: Self, o: Self) Self {
        return .{ .x = v.x + o.x, .y = v.y + o.y };
    }

    /// subtract two vectors
    pub fn sub(v: Self, o: Self) Self {
        return .{ .x = v.x - o.x, .y = v.y - o.y };
    }

    /// multiply a vector by a scalar
    pub fn scale(v: Self, s: f32) Self {
        return .{ .x = s * v.x, .y = s * v.y };
    }

    /// multiply a vector by a vector component-wise
    pub fn mul(v: Self, o: Self) Self {
        return .{ .x = v.x * o.x, .y = v.y * o.y };
    }

    /// the magnitude of a vector
    pub fn len(v: Self) f32 {
        return math.sqrt((v.x * v.x) + (v.y * v.y));
    }

    /// normalize the vector
    pub fn norm(v: Self) Self {
        const l = v.len();
        return .{ .x = v.x / l, .y = v.y / l };
    }

    /// dot product
    /// also the magnitude of each times
    /// the cos of the angle between them
    pub fn dot(v: Self, o: Self) f32 {
        return v.x * o.x + v.y * o.y;
    }

    /// the distance between two vectors
    pub fn dist(v: Self, o: Self) f32 {
        return math.sqrt((v.x - o.x) * (v.x - o.x) +
            (v.y - o.y) * (v.y - o.y));
    }
};

test "new" {
    // normal new
    var v = Vec2{ .x = 0.0, .y = 1.5 };
    var v1 = Vec2.new(-0.8, 1.5);

    try testing.expectEqual(v.x, 0);
    try testing.expectEqual(v.y, 1.5);
    try testing.expectEqual(v1.x, -0.8);
    try testing.expectEqual(v1.y, 1.5);
}

test "add/sub" {
    var v = Vec2{ .x = 0.0, .y = 1.5 };
    var v1 = Vec2.new(-0.8, 1.5);

    try testing.expectEqual(v.sub(v1), Vec2.new(0.8, 0));
    try testing.expectEqual(v.add(v1), Vec2.new(-0.8, 3));
}

test "scale/mul" {
    var v = Vec2{ .x = -0.5, .y = 1.5 };
    v = v.scale(1);
    try testing.expectEqual(v.x, -0.5);
    try testing.expectEqual(v.y, 1.5);
    var v1 = v.scale(2);
    try testing.expectEqual(v1.x, -1);
    try testing.expectEqual(v1.y, 3);

    var v2 = v1.mul(v);
    try testing.expectEqual(v2.x, 0.5);
    try testing.expectEqual(v2.y, 4.5);
}

test "len" {
    var v = Vec2.new(-0.8, 1.5);
    try testing.expectEqual(v.len(), 1.7);
}

test "norm" {
    var v = Vec2.new(-0.8, 1.5);
    var n = v.norm();
    try testing.expectApproxEqAbs(n.x, -0.47058823529, 0.001);
    try testing.expectApproxEqAbs(n.y, 0.88235294117, 0.001);
    v = Vec2.new(1, 0);
    try testing.expectEqual(v.norm(), Vec2.new(1, 0));
}

test "dot" {
    var a = Vec2.new(-0.8, 1.5);
    var b = Vec2.new(3, 2);
    try testing.expectApproxEqAbs(a.dot(b), 0.6, 0.001);
    try testing.expectApproxEqAbs(b.dot(a), 0.6, 0.001);
}

test "dist" {
    var a = Vec2.new(1, 2);
    var b = Vec2.new(1, 5);
    try testing.expectEqual(a.dist(b), 3);
    try testing.expectEqual(b.dist(a), 3);
}
