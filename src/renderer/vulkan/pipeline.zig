const std = @import("std");
const vk = @import("vulkan");
const PipelineDesc = @import("../rendertypes.zig").PipelineDesc;
const Device = @import("device.zig").Device;
const RenderPass = @import("renderpass.zig").RenderPass;
const CommandBuffer = @import("commandbuffer.zig").CommandBuffer;
const Mesh = @import("mesh.zig").Mesh;

pub const Pipeline = struct {
    const Self = @This();

    /// maximum number of shader stages
    const MAX_STAGES = 3;

    handle: vk.Pipeline = .null_handle,
    layout: vk.PipelineLayout = .null_handle,

    /// shader modules used in this pipeline
    modules: [MAX_STAGES]vk.ShaderModule = [_]vk.ShaderModule{.null_handle} ** MAX_STAGES,

    pub fn init(
        device: Device,
        desc: PipelineDesc,
        renderpass: vk.RenderPass,
        descriptor_set_layouts: []const vk.DescriptorSetLayout,
        push_constants: []const vk.PushConstantRange,
        wireframe: bool,
        vertex_inputs: []const vk.VertexInputBindingDescription,
        vertex_attrs: []const vk.VertexInputAttributeDescription,
        allocator: std.mem.Allocator,
    ) !Self {
        var self: Self = .{};

        if (desc.stages.len > MAX_STAGES) {
            return error.TooManyShaderStages;
        }

        // TODO: should these really be 1 since they are null?
        const viewport_state = vk.PipelineViewportStateCreateInfo{
            .flags = .{},
            .viewport_count = 1,
            .p_viewports = null,
            .scissor_count = 1,
            .p_scissors = null,
        };

        const cull_mode: vk.CullModeFlags = switch (desc.cull_mode) {
            .none => .{},
            .front => .{ .front_bit = true },
            .back => .{ .back_bit = true },
            .both => .{ .front_bit = true, .back_bit = true },
        };

        const rasterization_ci = vk.PipelineRasterizationStateCreateInfo{
            .flags = .{},
            .depth_clamp_enable = vk.FALSE,
            .rasterizer_discard_enable = vk.FALSE,
            .polygon_mode = if (wireframe) .line else .fill,
            .line_width = 1,
            .cull_mode = cull_mode,
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

        // dynamic state allows us to change stuff without recreating pipeline
        const dynamic_state = [_]vk.DynamicState{ .viewport, .scissor, .line_width };

        const dynamic_state_ci = vk.PipelineDynamicStateCreateInfo{
            .flags = .{},
            .dynamic_state_count = dynamic_state.len,
            .p_dynamic_states = &dynamic_state,
        };

        const binds = if (vertex_inputs.len == 0) undefined else @ptrCast([*]const vk.VertexInputBindingDescription, vertex_inputs);
        const attrs = if (vertex_attrs.len == 0) undefined else @ptrCast([*]const vk.VertexInputAttributeDescription, vertex_attrs);
        const vertex_input_ci = vk.PipelineVertexInputStateCreateInfo{
            .flags = .{},
            .vertex_binding_description_count = @intCast(u32, vertex_inputs.len),
            .p_vertex_binding_descriptions = binds,
            .vertex_attribute_description_count = @intCast(u32, vertex_attrs.len),
            .p_vertex_attribute_descriptions = attrs,
        };

        const input_assembly = vk.PipelineInputAssemblyStateCreateInfo{
            .flags = .{},
            .topology = .triangle_list,
            .primitive_restart_enable = vk.FALSE,
        };

        self.layout = try device.vkd.createPipelineLayout(device.logical, &.{
            .flags = .{},
            .set_layout_count = @intCast(u32, descriptor_set_layouts.len),
            .p_set_layouts = descriptor_set_layouts.ptr,
            .push_constant_range_count = @intCast(u32, push_constants.len),
            .p_push_constant_ranges = push_constants.ptr,
        }, null);

        // setup the stages
        var stage_infos: [MAX_STAGES]vk.PipelineShaderStageCreateInfo = undefined;
        for (desc.stages) |sd, i| {
            const stage_type: vk.ShaderStageFlags = switch (sd.bindpoint) {
                .Vertex => .{ .vertex_bit = true },
                .Fragment => .{ .fragment_bit = true },
            };

            const data = try loadShader(sd.path, allocator);

            self.modules[i] = try device.vkd.createShaderModule(device.logical, &.{
                .flags = .{},
                .code_size = data.len,
                .p_code = @ptrCast([*]const u32, @alignCast(4, data)),
            }, null);

            stage_infos[i] = .{
                .flags = .{},
                .stage = stage_type,
                .module = self.modules[i],
                .p_name = "main",
                .p_specialization_info = null,
            };

            allocator.free(data);
        }

        const gpci = vk.GraphicsPipelineCreateInfo{
            .flags = .{},
            .stage_count = @intCast(u32, desc.stages.len),
            .p_stages = &stage_infos,
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
            .render_pass = renderpass,
            .subpass = 0,
            .base_pipeline_handle = .null_handle,
            .base_pipeline_index = -1,
        };

        _ = try device.vkd.createGraphicsPipelines(
            device.logical,
            .null_handle,
            1,
            @ptrCast([*]const vk.GraphicsPipelineCreateInfo, &gpci),
            null,
            @ptrCast([*]vk.Pipeline, &self.handle),
        );

        return self;
    }

    fn loadShader(path: []const u8, alloctor: std.mem.Allocator) ![]u8 {
        std.log.info("finding file: {s}", .{path});

        const f = try std.fs.cwd().openFile(path, .{ .read = true });
        defer f.close();

        const ret = try alloctor.alloc(u8, (try f.stat()).size);

        _ = try f.readAll(ret);

        return ret;
    }

    pub fn deinit(
        self: Self,
        device: Device,
    ) void {
        for (self.modules) |m| {
            if (m != .null_handle) {
                device.vkd.destroyShaderModule(device.logical, m, null);
            }
        }
        device.vkd.destroyPipeline(device.logical, self.handle, null);
        device.vkd.destroyPipelineLayout(device.logical, self.layout, null);
    }
};
