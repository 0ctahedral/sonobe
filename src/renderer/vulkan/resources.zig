const std = @import("std");
const vk = @import("vulkan");
const FreeList = @import("../../containers.zig").FreeList;
const Device = @import("device.zig").Device;
const Buffer = @import("buffer.zig").Buffer;
const Sampler = @import("texture.zig").Sampler;
const RenderPass = @import("renderpass.zig").RenderPass;
const Pipeline = @import("pipeline.zig").Pipeline;
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
var samplers: FreeList(Sampler) = undefined;
var renderpasses: FreeList(RenderPass) = undefined;
var pipelines: FreeList(Pipeline) = undefined;

const MAX_BINDGROUPS = 1024;
/// stores layout and sets needed for updating a pipeline
const BindGroup = struct {
    bindings: [32]types.BindingDesc = undefined,
    n_bindings: u8 = 0,
    layout: vk.DescriptorSetLayout = .null_handle,
    sets: [MAX_FRAMES]vk.DescriptorSet = [_]vk.DescriptorSet{.null_handle} ** MAX_FRAMES,
};
var bind_groups: FreeList(BindGroup) = undefined;

const ResourceType = enum {
    Buffer,
    Texture,
    Sampler,
    BindGroup,
    RenderPass,
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
    Sampler: struct {
        index: u32,
        desc: types.SamplerDesc,
    },
    BindGroup: struct {
        index: u32,
    },
    RenderPass: struct {
        index: u32,
    },
    Pipeline: struct {
        index: u32,
    },
};

var resources: FreeList(Resource) = undefined;

var device: Device = undefined;

var descriptor_pool: vk.DescriptorPool = .null_handle;

var allocator: std.mem.Allocator = undefined;

pub fn init(_device: Device, _allocator: std.mem.Allocator) !void {
    device = _device;
    allocator = _allocator;

    resources = try FreeList(Resource).init(allocator, MAX_TEXTURES + MAX_BUFFERS);

    textures = try FreeList(Texture).init(allocator, MAX_TEXTURES);
    samplers = try FreeList(Sampler).init(allocator, MAX_TEXTURES);
    bind_groups = try FreeList(BindGroup).init(allocator, MAX_BINDGROUPS);
    renderpasses = try FreeList(RenderPass).init(allocator, 32);
    pipelines = try FreeList(Pipeline).init(allocator, 1024);

    for (buffers) |*buf| {
        buf.* = try FreeList(Buffer).init(allocator, MAX_BUFFERS / 4);
    }

    // create descriptor pool

    // TODO: configure?
    const count: u32 = MAX_BINDGROUPS * 1024;
    const descriptor_sizes = [_]vk.DescriptorPoolSize{
        // constants
        .{
            .@"type" = .uniform_buffer,
            .descriptor_count = count,
        },
        // data
        .{
            .@"type" = .storage_buffer,
            .descriptor_count = count,
        },
        // images
        .{
            .@"type" = .sampled_image,
            .descriptor_count = count,
        },
        // samplers
        .{
            .@"type" = .sampler,
            .descriptor_count = count,
        },
    };
    descriptor_pool = try device.vkd.createDescriptorPool(device.logical, &.{
        .flags = .{},
        .max_sets = MAX_BINDGROUPS,
        .pool_size_count = descriptor_sizes.len,
        .p_pool_sizes = &descriptor_sizes,
    }, null);
}

pub fn deinit() void {
    var res_iter = resources.iter();
    while (res_iter.next()) |t| {
        destroyResource(t.*);
    }

    device.vkd.destroyDescriptorPool(device.logical, descriptor_pool, null);

    textures.deinit();
    samplers.deinit();
    bind_groups.deinit();
    renderpasses.deinit();
    pipelines.deinit();

    for (buffers) |*buf| {
        buf.deinit();
    }

    resources.deinit();
}

fn destroyResource(res: Resource) void {
    switch (res) {
        .Texture => |t| {
            textures.get(t.index).deinit(device);
        },
        .Sampler => |s| {
            samplers.get(s.index).deinit(device);
        },
        .Buffer => |b| {
            buffers[@enumToInt(b.desc.usage)].get(b.index).deinit(device);
        },
        .BindGroup => |bg| {
            const layout = bind_groups.get(bg.index).layout;
            device.vkd.destroyDescriptorSetLayout(device.logical, layout, null);
        },
        .RenderPass => |rp| {
            renderpasses.get(rp.index).deinit(device);
        },
        .Pipeline => |pl| {
            pipelines.get(pl.index).deinit(device);
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
const Mat4 = @import("../../math.zig").Mat4;
const MeshPushConstants = struct {
    id: u32 align(16) = 0,
    model: Mat4 align(16) = Mat4.identity(),
};

pub fn createPipeline(desc: types.PipelineDesc) !Handle {
    const handle_idx = try resources.allocIndex();
    const pl_idx = try pipelines.allocIndex();

    // TODO: bounds check
    var dsl: [16]vk.DescriptorSetLayout = undefined;
    for (desc.binding_groups) |bgh, i| {
        dsl[i] = getBindGroup(bgh).layout;
    }

    pipelines.set(pl_idx, try Pipeline.init(
        device,
        desc,
        getRenderPass(desc.renderpass).handle,
        dsl[0..desc.binding_groups.len],
        &[_]vk.PushConstantRange{
            .{
                .stage_flags = .{ .vertex_bit = true },
                .offset = 0,
                .size = @intCast(u32, @sizeOf(MeshPushConstants)),
            },
        },
        false,
        allocator,
    ));

    resources.set(
        handle_idx,
        .{ .Pipeline = .{ .index = pl_idx } },
    );

    return Handle{ .resource = handle_idx };
}

pub fn createRenderPass(desc: types.RenderPassDesc) !Handle {
    const handle_idx = try resources.allocIndex();
    const rp_idx = try renderpasses.allocIndex();

    renderpasses.set(rp_idx, try RenderPass.init(
        device,
        // TODO: add swapchain surface format
        vk.Format.b8g8r8a8_srgb,
        desc,
    ));

    resources.set(
        handle_idx,
        .{ .RenderPass = .{ .index = rp_idx } },
    );

    return Handle{ .resource = handle_idx };
}

/// creates a binding group for a pipeline
pub fn createBindingGroup(binds: []const types.BindingDesc) !Handle {
    // create layout bindings in place
    var bindings: [32]vk.DescriptorSetLayoutBinding = undefined;
    if (binds.len > bindings.len) return error.TooManyBindings;

    const handle_idx = try resources.allocIndex();

    var bg = BindGroup{};
    bg.n_bindings = bindings.len;

    for (binds) |bind, i| {
        bindings[i] = .{
            .binding = @intCast(u32, i),
            .descriptor_type = switch (bind.binding_type) {
                // TODO: use different buffer types?
                .Buffer => .uniform_buffer,
                .Texture => .sampled_image,
                .Sampler => .sampler,
            },
            .descriptor_count = 1,
            .stage_flags = .{
                .vertex_bit = true,
                .fragment_bit = true,
                .compute_bit = true,
            },
            .p_immutable_samplers = null,
        };
        bg.bindings[i] = bind;
    }

    const data_idx = try bind_groups.allocIndex();
    // create the descriptor set layout
    bg.layout = try device.vkd.createDescriptorSetLayout(device.logical, &.{
        .flags = .{},
        .binding_count = @intCast(u32, binds.len),
        .p_bindings = &bindings,
    }, null);

    var layouts = [_]vk.DescriptorSetLayout{.null_handle} ** MAX_FRAMES;
    for (layouts) |*l| {
        l.* = bg.layout;
    }

    try device.vkd.allocateDescriptorSets(device.logical, &.{
        .descriptor_pool = descriptor_pool,
        .descriptor_set_count = bg.sets.len,
        .p_set_layouts = layouts[0..],
    }, @ptrCast([*]vk.DescriptorSet, &bg.sets));

    bind_groups.set(data_idx, bg);
    resources.set(
        handle_idx,
        .{ .BindGroup = .{ .index = data_idx } },
    );

    return Handle{ .resource = handle_idx };
}

// TODO: does this need a different home?
pub const BindingUpdate = struct {
    binding: u8,
    handle: Handle,
};
pub fn updateBindings(group: Handle, updates: []const BindingUpdate) !void {
    // get the group
    const bg: *BindGroup = bind_groups.get(resources.get(group.resource).BindGroup.index);

    if (updates.len > bg.n_bindings) return error.TooManyUpdates;

    var writes: [32 * MAX_FRAMES]vk.WriteDescriptorSet = undefined;

    // TODO: construct some descriptor set writes
    for (updates) |u, i| {
        if (u.binding > bg.n_bindings) return error.InvalidBinding;

        const b = bg.bindings[@intCast(usize, u.binding)];

        var desc_type: vk.DescriptorType = undefined;
        var image_infos: [1]vk.DescriptorImageInfo = undefined;
        var buffer_infos: [1]vk.DescriptorBufferInfo = undefined;
        switch (b.binding_type) {
            .Buffer => {
                // const buffer = buffers.get(resources.get(u.handle.resource).Buffer.index);
                // // TODO: set type here
                // desc_type = .uniform_buffer;
                // buffer_infos[0] = .{
                //     .buffer = buffer.handle,
                //     .offset = 0,
                //     .range = buffer.size,
                // };
            },
            .Sampler => {
                const sampler = samplers.get(resources.get(u.handle.resource).Sampler.index);
                desc_type = .sampler;
                image_infos[0] = .{
                    .sampler = sampler.handle,
                    .image_view = .null_handle,
                    .image_layout = .@"undefined",
                };
            },
            .Texture => {
                const tex = textures.get(resources.get(u.handle.resource).Texture.index);
                desc_type = .sampled_image;
                image_infos[0] = .{
                    .sampler = .null_handle,
                    .image_view = tex.image.view,
                    .image_layout = vk.ImageLayout.shader_read_only_optimal,
                };
            },
        }

        var j: usize = 0;
        while (j < MAX_FRAMES) : (j += 1) {
            writes[(i * MAX_FRAMES) + j] = .{
                .dst_set = bg.sets[j],
                .dst_binding = @intCast(u32, u.binding),
                .dst_array_element = 0,
                .descriptor_count = 1,
                .descriptor_type = desc_type,
                .p_image_info = image_infos[0..],
                .p_buffer_info = buffer_infos[0..],
                .p_texel_buffer_view = undefined,
            };
        }
    }

    device.vkd.updateDescriptorSets(device.logical, @intCast(u32, updates.len * MAX_FRAMES), &writes, 0, undefined);
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

// TODO: need to be able to update textures
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

pub fn createSampler(desc: types.SamplerDesc) !Handle {
    const handle_idx = try resources.allocIndex();
    const samp_idx = try samplers.allocIndex();

    samplers.set(samp_idx, try Sampler.init(device, desc));

    resources.set(
        handle_idx,
        .{ .Sampler = .{ .index = samp_idx, .desc = desc } },
    );

    return Handle{ .resource = handle_idx };
}

/// destroys a resource given the handle
pub inline fn destroy(handle: Handle) void {
    const res = resources.get(handle.resource);
    destroyResource(res.*);
    resources.freeIndex(handle.resource);
}

// TODO: should these go somewhere else? it kinda breaks the abstraction

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

pub fn getSampler(handle: Handle) *Sampler {
    const res = resources.get(handle.resource).Sampler;
    return samplers.get(res.index);
}

pub fn getBindGroup(handle: Handle) *BindGroup {
    const res = resources.get(handle.resource).BindGroup;
    return bind_groups.get(res.index);
}

pub fn getRenderPass(handle: Handle) *RenderPass {
    const res = resources.get(handle.resource).RenderPass;
    return renderpasses.get(res.index);
}

pub fn getPipeline(handle: Handle) *Pipeline {
    const res = resources.get(handle.resource).Pipeline;
    return pipelines.get(res.index);
}
