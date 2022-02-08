const std = @import("std");
const vk = @import("vulkan");
const Device = @import("device.zig").Device;
const RenderPass = @import("renderpass.zig").RenderPass;
const CommandBuffer = @import("commandbuffer.zig").CommandBuffer;
const Vertex = @import("mesh.zig").Vertex;

pub const Pipeline = struct {
    const Self = @This();

    handle: vk.Pipeline,
    layout: vk.PipelineLayout,

    pub fn init(
        dev: Device,
        renderpass: RenderPass,
        descriptor_set_layouts: []const vk.DescriptorSetLayout,
        stages: []const vk.PipelineShaderStageCreateInfo,
        viewport: vk.Viewport,
        scissor: vk.Rect2D,
        wireframe: bool,
    ) !Self {
        var self: Self = undefined;

        const viewport_state = vk.PipelineViewportStateCreateInfo{
            .flags = .{},
            .viewport_count = 1,
            .p_viewports = @ptrCast([*]const vk.Viewport, &viewport), 
            .scissor_count = 1,
            .p_scissors = @ptrCast([*]const vk.Rect2D, &scissor),
        };

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
            .set_layout_count = @intCast(u32, descriptor_set_layouts.len),
            .p_set_layouts = descriptor_set_layouts.ptr,
            .push_constant_range_count = 0,
            .p_push_constant_ranges = undefined,
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
        dev.vkd.destroyPipeline(dev.logical, self.handle, null);
        dev.vkd.destroyPipelineLayout(dev.logical, self.layout, null);
    }
};
