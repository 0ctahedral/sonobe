const vk = @import("vulkan");

const Vec3 = @import("../math.zig").Vec3;

/// A typical vertex layout in a mesh
pub const Vertex = struct {
    pos: Vec3,

    pub const binding_description = vk.VertexInputBindingDescription{
        .binding = 0,
        .stride = @sizeOf(Vertex),
        // one info per vertex
        .input_rate = .vertex,
    };

    pub const attribute_description = [_]vk.VertexInputAttributeDescription{
        .{
            .binding = 0,
            .location = 0,
            .format = .r32g32b32_sfloat,
            .offset = @offsetOf(Vertex, "pos"),
        },
        //.{
        //    .binding = 0,
        //    .location = 1,
        //    .format = .r32g32b32_sfloat,
        //    .offset = @offsetOf(Vertex, "color"),
        //},
    };
};

/// A mesh of vertices and corresponding indices
pub const Mesh = struct {
    verts: []const Vertex,
    inds: []const u32,
};

/// A rectangular mesh with vertices around the center
pub const Quad = Mesh{
    .verts = &.{
        .{ .pos = Vec3.new(-0.5, -0.5, 0) },
        .{ .pos = Vec3.new(0.5, 0.5, 0) },
        .{ .pos = Vec3.new(-0.5, 0.5, 0) },
        .{ .pos = Vec3.new(0.5, -0.5, 0) },
    },
    .inds = &.{ 0, 1, 2, 0, 3, 1 },
};
