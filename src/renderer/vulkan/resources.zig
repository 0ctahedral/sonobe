const std = @import("std");
const vk = @import("vulkan");
const FreeList = @import("../../containers.zig").FreeList;
const Device = @import("device.zig").Device;
const Buffer = @import("buffer.zig").Buffer;
const Texture = @import("texture.zig").Texture;
const MAX_FRAMES = @import("renderer.zig").MAX_FRAMES;

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
var buffers: [@typeInfo(types.BufferDesc.Usage).Enum.fields.len]FreeList(Buffer) = undefined;
/// textures to allocate from
const MAX_TEXTURES = 1024;
var textures: FreeList(Texture) = undefined;

/// stores layout and sets needed for updating a pipeline
const PipelineData = struct {
    layout: vk.DescriptorSetLayout,
    sets: [MAX_FRAMES]vk.DescriptorSet = [_]vk.DescriptorSet{.null_handle} ** MAX_FRAMES,
};
var pipeline_data: FreeList(PipelineData) = undefined;

const ResourceType = enum {
    Buffer,
    Texture,
    Pipeline,
};

// TODO: add sampler
// TODO: add shader/pipeline
const Resource = union(ResourceType) {
    Buffer: struct {
        /// index in buffer freelist
        index: u32,
        desc: types.BufferDesc,
    },
    Texture: struct {
        index: u32,
        desc: types.TextureDesc,
    },
    Pipeline: struct {
        index: u32,
        desc: types.PipelineDesc,
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
    pipeline_data = try FreeList(PipelineData).init(allocator, 64);
    for (buffers) |*buf| {
        buf.* = try FreeList(Buffer).init(allocator, MAX_BUFFERS / 4);
    }
}

pub fn deinit() void {
    var res_iter = resources.iter();
    while (res_iter.next()) |t| {
        destroyResource(t.*);
    }
    resources.deinit();
}

fn destroyResource(res: Resource) void {
    switch (res) {
        .Texture => |t| {
            textures.get(t.index).deinit(device);
        },
        .Buffer => |b| {
            buffers[@enumToInt(b.desc.usage)].get(b.index).deinit(device);
        },
        .Pipeline => |p| {
            const layout = pipeline_data.get(p.index).layout;
            device.vkd.destroyDescriptorSetLayout(device.logical, layout, null);
        },
    }
}

pub fn createBuffer(desc: types.BufferDesc) !Handle {
    // TODO: throw error if too big

    const res = try resources.allocIndex();
    // fix the types
    const usage: vk.BufferUsageFlags = switch (desc.usage) {
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
        .Storage => .{
            .storage_buffer_bit = true,
            .transfer_dst_bit = true,
        },
    };
    const size: usize = switch (desc.usage) {
        .Storage => 1024 * 1024,
        .Vertex => 1024 * 1024,
        .Index => 1024 * 1024,
    };

    const mem: vk.MemoryPropertyFlags = switch (desc.usage) {
        .Index, .Vertex => .{ .device_local_bit = true },
        .Storage => .{
            .host_visible_bit = true,
            .host_coherent_bit = true,
        },
    };

    const idx = try buffers[@enumToInt(desc.usage)].allocIndex();

    const buf = try Buffer.init(device, size, usage, mem, true);

    buffers[@enumToInt(desc.usage)].set(idx, buf);

    resources.set(res, .{ .Buffer = .{
        .index = idx,
        .desc = desc,
    } });

    last_vert += desc.size;

    const handle = Handle{ .resource = res };
    return handle;
}

pub fn createPipeline(desc: types.PipelineDesc) !Handle {
    // create layout bindings in place
    var bindings: [32]vk.DescriptorSetLayoutBinding = undefined;
    if (desc.bindings.len > bindings.len) return error.TooManyBindings;

    const handle_idx = try resources.allocIndex();

    for (desc.bindings) |handle, i| {
        // TODO: filter out handles of types that cannot be bound (another pipeline)
        bindings[i] = .{
            .binding = @intCast(u32, i),
            .descriptor_type = switch (resources.get(handle.resource).*) {
                .Buffer => .storage_buffer,
                .Texture => .sampled_image,
                .Pipeline => return error.CannotBindPipeline,
            },
            .descriptor_count = 1,
            .stage_flags = .{
                .vertex_bit = true,
                .fragment_bit = true,
                .compute_bit = true,
            },
            .p_immutable_samplers = null,
        };
        // std.log.debug("binding{d}: {}", .{ i, bindings[i] });
    }

    const data_idx = try pipeline_data.allocIndex();
    // create the descriptor set layout
    var ds_layout = try device.vkd.createDescriptorSetLayout(device.logical, &.{
        .flags = .{},
        .binding_count = @intCast(u32, desc.bindings.len),
        .p_bindings = &bindings,
    }, null);

    pipeline_data.set(data_idx, .{
        .layout = ds_layout,
    });

    // create the descriptor pool?
    // create the descriptor set?
    resources.set(
        handle_idx,
        .{ .Pipeline = .{ .index = data_idx, .desc = desc } },
    );

    return Handle{ .resource = handle_idx };
}

pub fn updateBuffer(handle: Handle, offset: usize, data: [*]const u8, size: usize) !void {
    // TODO: error if handle not found
    const res = resources.get(handle.resource).Buffer;

    // TODO: make this use the appropriate load type
    var buf = buffers[@enumToInt(res.desc.usage)].get(res.index);
    try buf.stagedLoad(
        device,
        device.command_pool,
        data,
        offset,
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

/// destroys a resource given the handle
pub inline fn destroy(handle: Handle) void {
    const res = resources.get(handle.resource);
    destroyResource(res.*);
    resources.freeIndex(handle.resource);
}

/// helper to get the buffer based on handle
pub fn getBuffer(handle: Handle) *Buffer {
    const res = resources.get(handle.resource).Buffer;
    return buffers[@enumToInt(res.desc.usage)].get(res.index);
}

/// helper to get a texture based on handle
pub fn getTexture(handle: Handle) *Texture {
    const res = resources.get(handle.resource).Texture;
    return textures.get(res.index);
}
