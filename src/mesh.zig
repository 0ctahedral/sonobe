const std = @import("std");
const renderer = @import("renderer.zig");
const resources = @import("renderer.zig").resources;
const mmath = @import("math.zig");
const Vec3 = mmath.Vec3;
const Vec2 = mmath.Vec2;
pub const Mesh = struct {
    positions: []const Vec3,
    uvs: []const Vec2,
    indices: []const u32,
    buffers: ?Buffers = null,

    pub fn getBuffers(self: *@This()) !Buffers {
        if (self.buffers) |b| return b;

        self.buffers = Buffers{
            .vertices = try resources.createBuffer(
                .{
                    .size = self.uvs.len * @sizeOf(Vec2) + self.positions.len * @sizeOf(Vec3),
                    .usage = .Vertex,
                },
            ),
            .indices = try resources.createBuffer(
                .{
                    .size = self.indices.len * @sizeOf(u32),
                    .usage = .Index,
                },
            ),
        };

        var offset = try renderer.updateBuffer(self.buffers.?.vertices, 0, Vec3, self.positions);
        offset = try renderer.updateBuffer(self.buffers.?.vertices, offset, Vec2, self.uvs);
        _ = try renderer.updateBuffer(self.buffers.?.indices, 0, u32, self.indices);

        return self.buffers.?;
    }
};

pub const Buffers = struct {
    vertices: renderer.Handle = .{},
    indices: renderer.Handle = .{},
};

pub const quad = &quad_data;
var quad_data = Mesh{
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
var cube_data = Mesh{
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
