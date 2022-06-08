const std = @import("std");
const builtin = @import("builtin");
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

pub const Mesh = struct {
    pos: []Vec3,
    texcoord: []Vec2,

    pub const info = getVertexInfo(@This());
};

fn VertexInfo(comptime T: type) type {
    const fields = @typeInfo(T).Struct.fields;
    return struct {
        bindings: [fields.len]vk.VertexInputBindingDescription = undefined,
        attrs: [fields.len]vk.VertexInputAttributeDescription = undefined,
    };
}

pub fn getVertexInfo(comptime T: type) VertexInfo(T) {
    const fields = @typeInfo(T).Struct.fields;

    var info: VertexInfo(T) = undefined;

    // print attribute types
    inline for (fields) |f, i| {
        switch (@typeInfo(f.field_type)) {
            .Pointer => |p| {
                switch (p.size) {
                    .Slice, .Many => {},
                    else => @compileError("expected field type to be slice or many"),
                }
                info.bindings[i] = .{
                    .binding = i,
                    .stride = @sizeOf(p.child),
                    // one info per vertex
                    .input_rate = .vertex,
                };
                info.attrs[i] = .{
                    .binding = i,
                    .location = i,
                    .format = typeToFormat(p.child),
                    .offset = 0,
                };
            },
            // must be a pointer type (slice)
            else => {
                @compileError("expected field type to be pointer type");
            },
        }
    }

    return info;
}

fn typeToFormat(comptime T: type) vk.Format {
    return switch (T) {
        Vec3 => .r32g32b32_sfloat,
        Vec2 => .r32g32_sfloat,
        f32 => .r32_sfloat,
        u8 => .r8_uint,
        u16 => .r16_uint,
        u32 => .r32_uint,
        u64 => .r64_uint,
        else => .@"undefined",
    };
}
