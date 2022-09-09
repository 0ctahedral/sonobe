const std = @import("std");
const vk = @import("vulkan");
pub const descs = @import("resources/descs.zig");
const MAX_FRAMES = @import("vulkan/backend.zig").MAX_FRAMES;

const FreeList = @import("containers").FreeList;
const Handle = @import("utils").Handle;

const Device = @import("vulkan/device.zig").Device;
const Buffer = @import("vulkan/buffer.zig").Buffer;
const Sampler = @import("vulkan/texture.zig").Sampler;
const RenderPass = @import("vulkan/renderpass.zig").RenderPass;
const Pipeline = @import("vulkan/pipeline.zig").Pipeline;
const Texture = @import("vulkan/texture.zig").Texture;

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
var buffers: [@typeInfo(descs.BufferDesc.Usage).Enum.fields.len]FreeList(Buffer) = undefined;
/// textures to allocate from
const MAX_TEXTURES = 1024;
var textures: FreeList(Texture) = undefined;
var samplers: FreeList(Sampler) = undefined;
var renderpasses: FreeList(RenderPass) = undefined;
var pipelines: FreeList(Pipeline) = undefined;

const MAX_BINDGROUPS = 1024;
/// stores layout and sets needed for updating a pipeline
const BindGroup = struct {
    bindings: [32]descs.BindingDesc = undefined,
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

const Resource = union(ResourceType) {
    Buffer: struct {
        /// index in buffer freelist
        index: u32,
        desc: descs.BufferDesc,
    },
    Texture: struct {
        index: u32,
        desc: descs.TextureDesc,
    },
    Sampler: struct {
        index: u32,
        desc: descs.SamplerDesc,
    },
    BindGroup: struct {
        index: u32,
    },
    RenderPass: struct {
        index: u32,
    },
    Pipeline: struct {
        index: u32,
        n_bind_groups: u8,
        bind_groups: [8]Handle(.BindGroup),
    },
};

pub var resources: FreeList(Resource) = undefined;

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

pub fn createBuffer(desc: descs.BufferDesc) !Handle(.Buffer) {
    // TODO: throw error if too big

    const res = try resources.allocIndex();
    // fix the descs
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
        .Uniform => .{
            .transfer_dst_bit = true,
            .uniform_buffer_bit = true,
        },
    };
    const mem: vk.MemoryPropertyFlags = switch (desc.usage) {
        .Index, .Vertex => .{ .device_local_bit = true },
        .Storage, .Uniform => .{
            .host_visible_bit = true,
            .host_coherent_bit = true,
        },
    };

    const idx = try buffers[@enumToInt(desc.usage)].allocIndex();

    const buf = try Buffer.init(device, desc.size, usage, mem, true);

    buffers[@enumToInt(desc.usage)].set(idx, buf);

    resources.set(res, .{ .Buffer = .{
        .index = idx,
        .desc = desc,
    } });

    last_vert += desc.size;

    const handle = Handle(.Buffer){ .id = res };
    return handle;
}

pub fn createPipeline(desc: descs.PipelineDesc) !Handle(.Pipeline) {
    const handle_idx = try resources.allocIndex();
    const pl_idx = try pipelines.allocIndex();

    var dsl: [16]vk.DescriptorSetLayout = undefined;
    if (desc.bind_groups.len > dsl.len) {
        return error.TooManyBindGroups;
    }
    for (desc.bind_groups) |bgh, i| {
        dsl[i] = getBindGroup(bgh).layout;
    }

    var input_bindings: [16]vk.VertexInputBindingDescription = undefined;
    var input_attrs: [16]vk.VertexInputAttributeDescription = undefined;
    if (desc.vertex_inputs.len > input_bindings.len) {
        return error.TooManyVertexInputs;
    }

    for (desc.vertex_inputs) |it, i| {
        input_bindings[i] = .{
            .binding = @intCast(u32, i),
            .stride = switch (it) {
                .Vec3 => @sizeOf(f32) * 3,
                .Vec2 => @sizeOf(f32) * 2,
                .f32 => @sizeOf(f32),
                .u8 => @sizeOf(u8),
                .u16 => @sizeOf(u16),
                .u32 => @sizeOf(u32),
                .u64 => @sizeOf(u64),
            },
            .input_rate = .vertex,
        };
        input_attrs[i] = .{
            .binding = @intCast(u32, i),
            .location = @intCast(u32, i),
            .format = switch (it) {
                .Vec3 => .r32g32b32_sfloat,
                .Vec2 => .r32g32_sfloat,
                .f32 => .r32_sfloat,
                .u8 => .r8_uint,
                .u16 => .r16_uint,
                .u32 => .r32_uint,
                .u64 => .r64_uint,
            },
            .offset = 0,
        };
    }

    const pcr = if (desc.push_const_size == 0) &[_]vk.PushConstantRange{} else &[_]vk.PushConstantRange{.{
        .stage_flags = .{ .vertex_bit = true, .fragment_bit = true },
        .offset = 0,
        .size = @as(u32, desc.push_const_size),
    }};

    pipelines.set(pl_idx, try Pipeline.init(
        device,
        desc,
        getRenderPass(desc.renderpass).handle,
        dsl[0..desc.bind_groups.len],
        pcr,
        desc.wireframe,
        input_bindings[0..desc.vertex_inputs.len],
        input_attrs[0..desc.vertex_inputs.len],
        allocator,
    ));

    var bgs = [_]Handle(.BindGroup){.{}} ** 8;
    for (desc.bind_groups) |h, i| {
        bgs[i] = h;
    }

    resources.set(
        handle_idx,
        .{ .Pipeline = .{
            .index = pl_idx,
            .n_bind_groups = @intCast(u8, desc.bind_groups.len),
            .bind_groups = bgs,
        } },
    );

    return Handle(.Pipeline){ .id = handle_idx };
}

pub fn createRenderPass(desc: descs.RenderPassDesc) !Handle(.RenderPass) {
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

    return Handle(.RenderPass){ .id = handle_idx };
}

/// creates a binding group for a pipeline
pub fn createBindGroup(binds: []const descs.BindingDesc) !Handle(.BindGroup) {
    // create layout bindings in place
    var bindings: [16]vk.DescriptorSetLayoutBinding = undefined;
    if (binds.len > bindings.len) return error.TooManyBindings;

    const handle_idx = try resources.allocIndex();

    var bg = BindGroup{};
    bg.n_bindings = bindings.len;

    for (binds) |bind, i| {
        bindings[i] = .{
            .binding = @intCast(u32, i),
            .descriptor_type = switch (bind.binding_type) {
                // TODO: use different buffer descs?
                .UniformBuffer => .uniform_buffer,
                .StorageBuffer => .storage_buffer,
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

    return Handle(.BindGroup){ .id = handle_idx };
}

// TODO: does this need a different home?
pub const BindingUpdate = struct {
    binding: u8,
    handle: Handle(null),
};
pub fn updateBindings(group: Handle(.BindGroup), updates: []const BindingUpdate) !void {
    // get the group
    const bg: *BindGroup = bind_groups.get(resources.get(group.id).BindGroup.index);

    if (updates.len > bg.n_bindings) return error.TooManyUpdates;

    var writes: [32 * MAX_FRAMES]vk.WriteDescriptorSet = undefined;

    for (updates) |u, i| {
        if (u.binding > bg.n_bindings) return error.InvalidBinding;

        const b = bg.bindings[@intCast(usize, u.binding)];

        var new_write: vk.WriteDescriptorSet = undefined;

        switch (b.binding_type) {
            .UniformBuffer, .StorageBuffer => {
                const res = resources.get(u.handle.id).Buffer;
                const buffer = buffers[@enumToInt(res.desc.usage)].get(res.index);
                const buf_infos = [_]vk.DescriptorBufferInfo{
                    .{
                        .buffer = buffer.handle,
                        .offset = 0,
                        .range = buffer.size,
                    },
                };

                const buffer_type: vk.DescriptorType = switch (res.desc.usage) {
                    .Uniform => .uniform_buffer,
                    .Storage => .storage_buffer,
                    else => return error.InvalidBufferType,
                };

                new_write = .{
                    .dst_set = bg.sets[0],
                    .dst_binding = u.binding,
                    .dst_array_element = 0,
                    .descriptor_count = 1,
                    .descriptor_type = buffer_type,
                    .p_image_info = undefined,
                    .p_buffer_info = buf_infos[0..],
                    .p_texel_buffer_view = undefined,
                };
            },
            .Texture => {
                const tex = textures.get(resources.get(u.handle.id).Texture.index);
                const tex_infos = [_]vk.DescriptorImageInfo{.{
                    .sampler = .null_handle,
                    .image_view = tex.image.view,
                    .image_layout = vk.ImageLayout.shader_read_only_optimal,
                }};

                new_write = .{
                    .dst_set = bg.sets[0],
                    .dst_binding = u.binding,
                    .dst_array_element = 0,
                    .descriptor_count = 1,
                    .descriptor_type = .sampled_image,
                    .p_image_info = tex_infos[0..],
                    .p_buffer_info = undefined,
                    .p_texel_buffer_view = undefined,
                };
            },
            .Sampler => {
                const sampler = samplers.get(resources.get(u.handle.id).Sampler.index);
                const sampler_infos = [_]vk.DescriptorImageInfo{.{
                    .sampler = sampler.handle,
                    .image_view = .null_handle,
                    .image_layout = .@"undefined",
                }};

                new_write = .{
                    .dst_set = bg.sets[0],
                    .dst_binding = u.binding,
                    .dst_array_element = 0,
                    .descriptor_count = 1,
                    .descriptor_type = .sampler,
                    .p_image_info = sampler_infos[0..],
                    .p_buffer_info = undefined,
                    .p_texel_buffer_view = undefined,
                };
            },
        }

        var j: usize = 0;
        while (j < MAX_FRAMES) : (j += 1) {
            new_write.dst_set = bg.sets[j];
            writes[(i * MAX_FRAMES) + j] = new_write;
        }
    }
    device.vkd.updateDescriptorSets(device.logical, @intCast(u32, updates.len * MAX_FRAMES), &writes, 0, undefined);
}

pub fn updateBuffer(
    handle: Handle(.Buffer),
    offset: usize,
    data: [*]const u8,
    size: usize,
) !void {
    // TODO: error if handle not found
    const res = resources.get(handle.id).Buffer;

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

pub fn updateBufferTyped(
    handle: Handle(.Buffer),
    offset: usize,
    comptime T: type,
    data: []const T,
) !usize {
    const size = @sizeOf(T) * data.len;
    try updateBuffer(
        handle,
        offset,
        @ptrCast([*]const u8, data),
        size,
    );
    return size + offset;
}

// TODO: put this somewhere
pub fn flipData(width: usize, height: usize, data: []u8) void {
    var i: usize = 0;
    while (i < height / 2) : (i += 1) {
        var j: usize = 0;
        while (j < width) : (j += 1) {
            const p1 = (i * width) + j;
            const p2 = (((height - 1) - i) * width) + j;
            const a = data[p2];
            data[p2] = data[p1];
            data[p1] = a;
        }
    }
}

pub fn createTexture(desc: descs.TextureDesc, data: []u8) !Handle(.Texture) {
    const handle_idx = try resources.allocIndex();
    const tex_idx = try textures.allocIndex();

    textures.set(tex_idx, try Texture.init(device, desc, data[0..]));

    resources.set(
        handle_idx,
        .{ .Texture = .{ .index = tex_idx, .desc = desc } },
    );

    return Handle(.Texture){ .id = handle_idx };
}

pub fn createTextureEmpty(desc: descs.TextureDesc) !Handle(.Texture) {
    const handle_idx = try resources.allocIndex();
    const tex_idx = try textures.allocIndex();

    textures.set(tex_idx, try Texture.initEmpty(device, desc));

    resources.set(
        handle_idx,
        .{ .Texture = .{ .index = tex_idx, .desc = desc } },
    );

    return Handle(.Texture){ .id = handle_idx };
}
/// update data in a texture at an offset
pub fn updateTexture(
    handle: Handle(.Texture),
    // offset into the buffer
    offset: u32,
    data: []u8,
    //TODO: make a struct for this
    offset_x: u32,
    offset_y: u32,
    extent_x: u32,
    extent_y: u32,
) !void {
    const res = resources.get(handle.id).Texture;
    var tex = textures.get(res.index);
    try tex.writeRegion(device, offset, data, offset_x, offset_y, extent_x, extent_y);
}

pub fn createSampler(desc: descs.SamplerDesc) !Handle(.Sampler) {
    const handle_idx = try resources.allocIndex();
    const samp_idx = try samplers.allocIndex();

    samplers.set(samp_idx, try Sampler.init(device, desc));

    resources.set(
        handle_idx,
        .{ .Sampler = .{ .index = samp_idx, .desc = desc } },
    );

    return Handle(.Sampler){ .id = handle_idx };
}

/// destroys a resource given the handle
pub inline fn destroy(handle: Handle(null)) void {
    const res = resources.get(handle.id);
    destroyResource(res.*);
    resources.freeIndex(handle.id);
}

// TODO: should these go somewhere else? it kinda breaks the abstraction

/// helper to get the buffer based on handle
pub fn getBuffer(handle: Handle(.Buffer)) *Buffer {
    const res = resources.get(handle.id).Buffer;
    return buffers[@enumToInt(res.desc.usage)].get(res.index);
}

/// helper to get a texture based on handle
pub fn getTexture(handle: Handle(.Texture)) *Texture {
    const res = resources.get(handle.id).Texture;
    return textures.get(res.index);
}

pub fn getSampler(handle: Handle(.Sampler)) *Sampler {
    const res = resources.get(handle.id).Sampler;
    return samplers.get(res.index);
}

pub fn getBindGroup(handle: Handle(.BindGroup)) *BindGroup {
    const res = resources.get(handle.id).BindGroup;
    return bind_groups.get(res.index);
}

pub fn getRenderPass(handle: Handle(.RenderPass)) *RenderPass {
    const res = resources.get(handle.id).RenderPass;
    return renderpasses.get(res.index);
}

pub fn getPipeline(handle: Handle(.Pipeline)) *Pipeline {
    const res = resources.get(handle.id).Pipeline;
    return pipelines.get(res.index);
}
