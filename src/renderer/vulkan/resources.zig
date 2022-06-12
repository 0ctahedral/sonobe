const std = @import("std");
const vk = @import("vulkan");
const FreeList = @import("../../containers.zig").FreeList;
const Device = @import("device.zig").Device;
const Buffer = @import("buffer.zig").Buffer;
const Texture = @import("texture.zig").Texture;

const types = @import("../rendertypes.zig");

const Handle = types.Handle;

/// the GPU side buffer that store the currenlty rendering objects
/// this one stores the indices of all geometry
/// TODO: will eventually be moved to another struct possibly
// pub var global_ind_buf: Buffer = undefined;
/// last offset in the index buffer
var last_ind: usize = 0;
/// this one stores the vertex data of all geometry
// pub var global_vert_buf: Buffer = undefined;
/// last offset in the vertex buffer
var last_vert: usize = 0;

/// backing buffers we are using for allocating from
const MAX_BUFFERS = 1024;
pub var buffers: [@typeInfo(types.BufferDesc.Usage).Enum.fields.len]Buffer = undefined;
/// textures to allocate from
const MAX_TEXTURES = 1024;
pub var textures: FreeList(Texture) = undefined;

const ResourceType = enum {
    Buffer,
    Texture,
};

const Resource = union(ResourceType) {
    Buffer: struct {
        /// offset in buffer
        offset: usize,
        desc: types.BufferDesc,
    },
    Texture: struct {
        index: u32,
        desc: types.TextureDesc,
    },
};

var resources: FreeList(Resource) = undefined;

var device: Device = undefined;

var allocator: std.mem.Allocator = undefined;

pub fn init(_device: Device, _allocator: std.mem.Allocator) !void {
    device = _device;
    allocator = _allocator;

    resources = try FreeList(Resource).init(allocator, MAX_TEXTURES + MAX_BUFFERS);
    textures = try FreeList(Texture).init(allocator, MAX_TEXTURES);

    for (buffers) |*buf, i| {
        const usage_type = @intToEnum(types.BufferDesc.Usage, i);

        // fix the types
        const usage: vk.BufferUsageFlags = switch (usage_type) {
            .Vertex => .{
                .vertex_buffer_bit = true,
                .transfer_src_bit = true,
                .transfer_dst_bit = true,
            },
            .Index => .{
                .index_buffer_bit = true,
                .transfer_src_bit = true,
                .transfer_dst_bit = true,
            },
        };

        const size: usize = switch (usage_type) {
            .Vertex => 1024 * 1024,
            .Index => @sizeOf(u32) * 1024 * 1024,
        };

        const mem: vk.MemoryPropertyFlags = switch (usage_type) {
            .Index, .Vertex => .{ .device_local_bit = true },
        };

        buf.* = try Buffer.init(device, size, usage, mem, true);
    }
}

pub fn deinit() void {
    for (buffers) |b| {
        b.deinit(device);
    }
    var tex_iter = textures.iter();
    while (tex_iter.next()) |t| {
        t.deinit(device);
    }
    resources.deinit();
}

pub fn createBuffer(desc: types.BufferDesc) !Handle {
    // TODO: throw error if too big

    const idx = try resources.allocIndex();
    const buf_offest = switch (desc.usage) {
        .Vertex => last_vert,
        .Index => last_ind,
        // else => last_vert,
    };
    resources.set(idx, .{ .Buffer = .{
        .offset = buf_offest,
        .desc = desc,
    } });

    last_vert += desc.size;

    const handle = Handle{ .resource = idx };
    return handle;
}

pub fn updateBuffer(handle: Handle, offset: usize, data: [*]const u8, size: usize) !void {
    // TODO: error if handle not found
    const res = resources.get(handle.resource).Buffer;

    // TODO: make this use the appropriate buffer based on the handle
    try buffers[@enumToInt(res.desc.usage)].stagedLoad(
        device,
        device.command_pool,
        data,
        res.offset + offset,
        size,
    );
}

pub fn createTexture(desc: types.TextureDesc, data: []const u8) !Handle {
    const handle_idx = try resources.allocIndex();

    _ = desc;
    const tex_idx = try textures.allocIndex();

    textures.set(tex_idx, try Texture.init(
        device,
        desc.width,
        desc.height,
        desc.depth,
        desc.channels,
        .{},
        data[0..],
    ));

    resources.set(
        handle_idx,
        .{ .Texture = .{ .index = tex_idx, .desc = desc } },
    );

    return Handle{ .resource = handle_idx };
}

/// currently buffers are bump allocators so this does not actually free any memory
pub fn destroy(handle: Handle) void {
    const res = resources.get(handle.resource);

    switch (res.*) {
        .Texture => |t| {
            textures.get(t.index).deinit(device);
        },
        else => {},
    }

    resources.freeIndex(handle.resource);
}

/// helper to get the backing buffer based on usage
pub fn getBackingBuffer(usage: types.BufferDesc.Usage) Buffer {
    return buffers[@enumToInt(usage)];
}

/// helper to get the resource from the freelist
pub fn getResource(handle: Handle) *Resource {
    return resources.get(handle.resource);
}
