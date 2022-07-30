const std = @import("std");
const mmath = @import("octal").mmath;

const Vec3 = mmath.Vec3;
const Vec2 = mmath.Vec2;

pub const positions = [_]Vec3{
    Vec3.new(-0.5, -0.5, 0),
    Vec3.new(0.5, 0.5, 0),
    Vec3.new(-0.5, 0.5, 0),
    Vec3.new(0.5, -0.5, 0),
};
pub const uvs = [_]Vec2{
    Vec2.new(0.0, 0.0),
    Vec2.new(1.0, 1.0),
    Vec2.new(0.0, 1.0),
    Vec2.new(1.0, 0.0),
};
pub const indices = [_]u32{ 0, 1, 2, 0, 3, 1 };
