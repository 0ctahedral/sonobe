const std = @import("std");
const vk = @import("vulkan");
const Device = @import("device.zig").Device;
const RenderPass = @import("renderpass.zig").RenderPass;
const CommandBuffer = @import("commandbuffer.zig").CommandBuffer;
const Vertex = @import("mesh.zig").Vertex;
const Renderer = @import("../renderer.zig");

pub const PipelineInfo = struct {
    pub const Resource = struct {
        type: enum {
            /// uniform buffer
            uniform,
            /// storage buffer
            storage,
            /// texture sampler
            sampler,
        },

        stage: vk.ShaderStageFlags,
    };

    pub const Constant = struct {
        size: u32,

        stage: vk.ShaderStageFlags,
    };

    /// This will be an api around descriptor sets and stuff
    pub const Stage = struct {
        path: []const u8,
    };

    constants: []const Constant,

    resources: []const Resource,

    wireframe: bool = false,

    vertex: ?Stage,
    fragment: ?Stage,

    pub const Context = struct {
        const K = PipelineInfo;
        pub fn hash(self: Context, k: K) u32 {
            var h = std.hash.Wyhash.init(0);
            _ = self;

            h.update(std.mem.asBytes(&k.vertex));
            h.update(std.mem.asBytes(&k.fragment));
            h.update(std.mem.asBytes(&k.wireframe));

            for (k.resources) |res| {
                h.update(std.mem.asBytes(&res));
            }

            return @truncate(u32, h.final());
        }

        pub fn eql(self: Context, a: K, b: K) bool {
            _ = self;
            var match = a.resources.len == b.resources.len;

            if (match) {
                for (a.resources) |res, i| {
                    match = match and std.meta.eql(res, b.resources[i]);
                }
            } else {
                return false;
            }

            return match and (a.wireframe == b.wireframe) and
                std.meta.eql(a.vertex, b.vertex) and
                std.meta.eql(a.fragment, b.fragment);
        }
    };
};

pub const Pipeline = struct {
    const Self = @This();

    // TOOD: up this to device min
    const MAX_DESCRIPTORS = 1;

    handle: vk.Pipeline = .null_handle,
    layout: vk.PipelineLayout = .null_handle,
    descriptor_layouts: [MAX_DESCRIPTORS]vk.DescriptorSetLayout,
    // TODO: freelist of descriptors? max frames?
    descriptors: [3][MAX_DESCRIPTORS]vk.DescriptorSet,

    pub fn init(
        dev: Device,
        renderpass: RenderPass,
        info: PipelineInfo,
        descriptor_pool: vk.DescriptorPool,
        wireframe: bool,
        allocator: std.mem.Allocator,
    ) !Self {
        var self: Self = undefined;

        var stage_ci: [3]vk.PipelineShaderStageCreateInfo = undefined;
        var shader_modules: [3]vk.ShaderModule = undefined;
        var n_stages: usize = 0;

        if (info.vertex) |vert| {
            const shader_info = try loadSpv(dev, vert.path, .{ .vertex_bit = true }, allocator);
            stage_ci[n_stages] = shader_info.info;
            shader_modules[n_stages] = shader_info.module;
            n_stages += 1;
        }

        if (info.fragment) |frag| {
            const shader_info = try loadSpv(dev, frag.path, .{ .fragment_bit = true }, allocator);
            stage_ci[n_stages] = shader_info.info;
            shader_modules[n_stages] = shader_info.module;
            n_stages += 1;
        }

        var stages: []const vk.PipelineShaderStageCreateInfo = stage_ci[0..n_stages];

        defer {
            for (shader_modules[0..n_stages]) |stage| {
                dev.vkd.destroyShaderModule(dev.logical, stage, null);
            }
        }

        // TODO: make a max bindings
        var bindings: [10]vk.DescriptorSetLayoutBinding = undefined;
        for (info.resources) |in, i| {
            bindings[i] = .{
                .binding = @intCast(u32, i),
                .descriptor_type = switch (in.type) {
                    .uniform => .uniform_buffer,
                    .storage => .storage_buffer,
                    else => @panic("implement more descriptor types"),
                },
                .descriptor_count = 1,
                .stage_flags = in.stage,
                .p_immutable_samplers = null,
            };
        }

        var push_constants: [10]vk.PushConstantRange = undefined;
        for (info.constants) |c, i| {
            push_constants[i] = .{
                .offset = 0,
                .stage_flags = c.stage,
                .size = c.size,
            };
        }

        const descriptor_layout = try dev.vkd.createDescriptorSetLayout(dev.logical, &.{
            .flags = .{},
            .binding_count = @intCast(u32, info.resources.len),
            .p_bindings = &bindings,
        }, null);
        self.descriptor_layouts[0] = descriptor_layout;

        for (self.descriptors) |*desc| {
            try dev.vkd.allocateDescriptorSets(dev.logical, &.{
                .descriptor_pool = descriptor_pool,
                .descriptor_set_count = 1,
                .p_set_layouts = &self.descriptor_layouts,
            }, @ptrCast([*]vk.DescriptorSet, desc));
        }
        _ = descriptor_pool;
        std.log.debug("got here", .{});

        const rasterization_ci = vk.PipelineRasterizationStateCreateInfo{
            .flags = .{},
            .depth_clamp_enable = vk.FALSE,
            .rasterizer_discard_enable = vk.FALSE,
            .polygon_mode = if (wireframe) .line else .fill,
            .line_width = 1,
            .cull_mode = .{ .back_bit = true },
            .front_face = .counter_clockwise,
            .depth_bias_enable = vk.FALSE,
            .depth_bias_constant_factor = 0,
            .depth_bias_clamp = 0,
            .depth_bias_slope_factor = 0,
        };

        const multi_sample_ci = vk.PipelineMultisampleStateCreateInfo{
            .flags = .{},
            .rasterization_samples = .{ .@"1_bit" = true },
            .sample_shading_enable = vk.FALSE,
            .min_sample_shading = 1,
            .p_sample_mask = null,
            .alpha_to_coverage_enable = vk.FALSE,
            .alpha_to_one_enable = vk.FALSE,
        };

        const depth_stencil_ci = vk.PipelineDepthStencilStateCreateInfo{
            .flags = .{},
            .depth_test_enable = vk.TRUE,
            .depth_write_enable = vk.TRUE,
            .depth_compare_op = .less,
            .depth_bounds_test_enable = vk.FALSE,
            .stencil_test_enable = vk.FALSE,
            .front = undefined,
            .back = undefined,
            .min_depth_bounds = 0,
            .max_depth_bounds = 1,
        };

        const color_blend_state = vk.PipelineColorBlendAttachmentState{
            .blend_enable = vk.TRUE,
            .src_color_blend_factor = .src_alpha,
            .dst_color_blend_factor = .one_minus_src_alpha,
            .color_blend_op = .add,
            .src_alpha_blend_factor = .src_alpha,
            .dst_alpha_blend_factor = .one_minus_src_alpha,
            .alpha_blend_op = .add,
            .color_write_mask = .{ .r_bit = true, .g_bit = true, .b_bit = true, .a_bit = true },
        };

        const color_blend_state_ci = vk.PipelineColorBlendStateCreateInfo{
            .flags = .{},
            .logic_op_enable = vk.FALSE,
            .logic_op = .copy,
            .attachment_count = 1,
            .p_attachments = @ptrCast([*]const vk.PipelineColorBlendAttachmentState, &color_blend_state),
            .blend_constants = [_]f32{ 0, 0, 0, 0 },
        };

        const viewport_state = vk.PipelineViewportStateCreateInfo{
            .flags = .{},
            .viewport_count = 1,
            .p_viewports = undefined,
            .scissor_count = 1,
            .p_scissors = undefined,
        };

        // dynamic state allows us to change stuff without recreating pipeline
        const dynamic_state = [_]vk.DynamicState{ .viewport, .scissor, .line_width };

        const dynamic_state_ci = vk.PipelineDynamicStateCreateInfo{
            .flags = .{},
            .dynamic_state_count = dynamic_state.len,
            .p_dynamic_states = &dynamic_state,
        };

        const vertex_input_ci = vk.PipelineVertexInputStateCreateInfo{
            .flags = .{},
            .vertex_binding_description_count = 1,
            .p_vertex_binding_descriptions = @ptrCast([*]const vk.VertexInputBindingDescription, &Vertex.binding_description),
            .vertex_attribute_description_count = @intCast(u32, Vertex.attribute_description.len),
            .p_vertex_attribute_descriptions = &Vertex.attribute_description,
        };

        const input_assembly = vk.PipelineInputAssemblyStateCreateInfo{
            .flags = .{},
            .topology = .triangle_list,
            .primitive_restart_enable = vk.FALSE,
        };

        self.layout = try dev.vkd.createPipelineLayout(dev.logical, &.{
            .flags = .{},
            .set_layout_count = @intCast(u32, self.descriptor_layouts.len),
            .p_set_layouts = self.descriptor_layouts[0..],
            .push_constant_range_count = @intCast(u32, info.constants.len),
            .p_push_constant_ranges = &push_constants,
        }, null);

        const gpci = vk.GraphicsPipelineCreateInfo{
            .flags = .{},
            .stage_count = @intCast(u32, stages.len),
            .p_stages = stages.ptr,
            .p_vertex_input_state = &vertex_input_ci,
            .p_input_assembly_state = &input_assembly,
            .p_tessellation_state = null,
            .p_viewport_state = &viewport_state,
            .p_rasterization_state = &rasterization_ci,
            .p_multisample_state = &multi_sample_ci,
            .p_depth_stencil_state = &depth_stencil_ci,
            .p_color_blend_state = &color_blend_state_ci,
            .p_dynamic_state = &dynamic_state_ci,
            .layout = self.layout,
            .render_pass = renderpass.handle,
            .subpass = 0,
            .base_pipeline_handle = .null_handle,
            .base_pipeline_index = -1,
        };

        _ = try dev.vkd.createGraphicsPipelines(
            dev.logical,
            .null_handle,
            1,
            @ptrCast([*]const vk.GraphicsPipelineCreateInfo, &gpci),
            null,
            @ptrCast([*]vk.Pipeline, &self.handle),
        );

        return self;
    }

    pub fn bind(
        self: Self,
        dev: Device,
        cmd_buf: CommandBuffer,
        bind_point: vk.PipelineBindPoint,
    ) void {
        dev.vkd.cmdBindPipeline(cmd_buf.handle, bind_point, self.handle);
    }

    pub fn deinit(
        self: Self,
        dev: Device,
    ) void {
        for (self.descriptor_layouts) |desc| {
            dev.vkd.destroyDescriptorSetLayout(dev.logical, desc, null);
        }
        dev.vkd.destroyPipeline(dev.logical, self.handle, null);
        dev.vkd.destroyPipelineLayout(dev.logical, self.layout, null);
    }

    pub fn getDescriptors(self: *Self) []vk.DescriptorSet {
        return &self.descriptors[Renderer.swapchain.image_index];
    }
};

pub const ShaderInfo = struct {
    module: vk.ShaderModule,
    info: vk.PipelineShaderStageCreateInfo,
};

pub fn loadSpv(dev: Device, path: []const u8, stage: vk.ShaderStageFlags, allocator: std.mem.Allocator) !ShaderInfo {
    std.log.info("finding file: {s}", .{path});

    const f = try std.fs.cwd().openFile(path, .{ .read = true });
    defer f.close();

    const data = try allocator.alloc(u8, (try f.stat()).size);

    _ = try f.readAll(data);

    const mod = try dev.vkd.createShaderModule(dev.logical, &.{
        .flags = .{},
        .code_size = data.len,
        .p_code = @ptrCast([*]const u32, @alignCast(4, data)),
    }, null);

    const ci = vk.PipelineShaderStageCreateInfo{
        .flags = .{},
        .stage = stage,
        .module = mod,
        .p_name = "main",
        .p_specialization_info = null,
    };

    return ShaderInfo{
        .module = mod,
        .info = ci,
    };
}
