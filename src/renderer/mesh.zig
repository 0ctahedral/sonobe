const vk = @import("vulkan");
const mmath = @import("../math.zig");
const Vec3 = mmath.Vec3;
const Vec2 = mmath.Vec2;

pub const Vertex = struct {
    //TODO: make a generator for binding descriptions

    pos: Vec3,
    texcoord: Vec2,

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
        .{
            .binding = 0,
            .location = 1,
            .format = .r32g32_sfloat,
            .offset = @offsetOf(Vertex, "texcoord"),
        },
    };
};
