const std = @import("std");
const mmath = @import("math.zig");
const Vec3 = mmath.Vec3;
const Vec2 = mmath.Vec2;

pub const Mesh = struct {
    positions: []const Vec3,
    uvs: []const Vec2,
    indices: []const u32,
};

pub const quad = Mesh{
    .positions = &[_]Vec3{
        Vec3.new(-0.5, -0.5, 0),
        Vec3.new(0.5, 0.5, 0),
        Vec3.new(-0.5, 0.5, 0),
        Vec3.new(0.5, -0.5, 0),
    },
    .uvs = &[_]Vec2{
        Vec2.new(0.0, 0.0),
        Vec2.new(1.0, 1.0),
        Vec2.new(0.0, 1.0),
        Vec2.new(1.0, 0.0),
    },
    .indices = &[_]u32{ 0, 1, 2, 0, 3, 1 },
};
pub const cube = Mesh{
    .positions = &[_]Vec3{
        Vec3.new(-1.00, -1.00, -1.00),
        Vec3.new(1.00, -1.00, -1.00),
        Vec3.new(-1.00, 1.00, -1.00),
        Vec3.new(1.00, 1.00, -1.00),
        Vec3.new(-1.00, -1.00, 1.00),
        Vec3.new(1.00, -1.00, 1.00),
        Vec3.new(-1.00, 1.00, 1.00),
        Vec3.new(1.00, 1.00, 1.00),
    },

    .indices = &[_]u32{
        // back face
        1, 0, 3, //
        3, 0, 2, //

        // front face
        4, 5, 6, //
        5, 7, 6, //

        // left face
        2, 0, 4, //
        4, 6, 2, //

        // right face
        5, 1, 7, //
        7, 1, 3, //

        // top face
        2, 6, 7,
        7, 3, 2,

        // bottom face
        4, 0, 1,
        1, 5, 4,
    },

    .uvs = &[_]Vec2{
        Vec2.new(0.0, 0.0),
        Vec2.new(1.0, 0.0),
        Vec2.new(0.0, 1.0),
        Vec2.new(1.0, 1.0),
        Vec2.new(0.0, 0.0),
        Vec2.new(1.0, 0.0),
        Vec2.new(0.0, 1.0),
        Vec2.new(1.0, 1.0),
    },
};
