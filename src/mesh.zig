const std = @import("std");
const sonobe = @import("sonobe.zig");
const renderer = sonobe.renderer;
const resources = renderer.resources;
const math = sonobe.math;
const Vec3 = math.Vec3;
const Vec2 = math.Vec2;

pub const gltf = @import("mesh/gltf.zig");
pub const Mesh = @import("mesh/mesh.zig").Mesh;
pub const ConstMesh = @import("mesh/mesh.zig").ConstMesh;

pub const quad = &quad_data;
var quad_data = ConstMesh{
    .positions = &[_]Vec3{
        Vec3.new(-0.5, -0.5, 0),
        Vec3.new(0.5, 0.5, 0),
        Vec3.new(-0.5, 0.5, 0),
        Vec3.new(0.5, -0.5, 0),
    },
    .uvs = &[_]Vec2{
        Vec2.new(0.0, 1.0),
        Vec2.new(1.0, 0.0),
        Vec2.new(0.0, 0.0),
        Vec2.new(1.0, 1.0),
    },
    .indices = &[_]u32{ 0, 1, 2, 0, 3, 1 },
};

pub const cube = &cube_data;
var cube_data = ConstMesh{
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
        Vec2.new(-0.5, -0.5),
        Vec2.new(0.5, -0.5),
        Vec2.new(-0.5, 0.5),
        Vec2.new(0.5, 0.5),
        Vec2.new(-0.5, -0.5),
        Vec2.new(0.5, -0.5),
        Vec2.new(-0.5, 0.5),
        Vec2.new(0.5, 0.5),
    },
};
