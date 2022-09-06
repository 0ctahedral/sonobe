const std = @import("std");
const testing = std.testing;
const math = std.math;
const util = @import("util.zig");
// im being lazy so this will all be in f32 and can be changed later
// TODO: swizzel?

pub const Vec4 = struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,
    w: f32 = 0,

    const Self = @This();

    /// convinience function to create a new Vec without struct syntax
    pub inline fn new(x: f32, y: f32, z: f32, w: f32) Self {
        return .{ .x = x, .y = y, .z = z, .w = w };
    }

    pub fn eql(l: Self, r: Self) bool {
        return (l.x == r.x and l.y == r.y and l.z == r.z and l.w == r.w);
    }

    /// add two vectors
    pub fn add(v: Self, o: Self) Self {
        return .{ .x = v.x + o.x, .y = v.y + o.y, .z = v.z + o.z, .w = v.w + o.w };
    }

    /// subtract two vectors
    pub fn sub(v: Self, o: Self) Self {
        return .{ .x = v.x - o.x, .y = v.y - o.y, .z = v.z - o.z, .w = v.w - o.w };
    }

    /// multiply a vector by a scalar
    pub fn scale(v: Self, s: f32) Self {
        return .{ .x = s * v.x, .y = s * v.y, .z = s * v.z, .w = s * v.w };
    }

    /// multiply a vector by a vector component-wise
    pub fn mul(v: Self, o: Self) Self {
        return .{ .x = v.x * o.x, .y = v.y * o.y, .z = v.z * o.z, .w = v.w * o.w };
    }

    /// the magnitude of a vector
    pub fn len(v: Self) f32 {
        return math.sqrt((v.x * v.x) + (v.y * v.y) + (v.z * v.z) + (v.w * v.w));
    }

    /// normalize the vector
    pub fn norm(v: Self) Self {
        const l = v.len();
        return .{ .x = v.x / l, .y = v.y / l, .z = v.z / l, .w = v.w / l };
    }

    /// the distance between two vectors
    pub fn dist(v: Self, o: Self) f32 {
        return math.sqrt((v.x - o.x) * (v.x - o.x) +
            (v.y - o.y) * (v.y - o.y) +
            (v.z - o.z) * (v.z - o.z)(v.w - o.w) * (v.w - o.w));
    }

    /// lerp
    pub fn lerp(l: Self, r: Self, t: f32) Self {
        return Self.new(
            util.lerp(l.x, r.x, t),
            util.lerp(l.y, r.y, t),
            util.lerp(l.z, r.z, t),
            util.lerp(l.w, r.w, t),
        );
    }
};
