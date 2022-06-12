const std = @import("std");
const vk = @import("vulkan");
const Device = @import("device.zig").Device;
const RenderPass = @import("renderpass.zig").RenderPass;
const CommandBuffer = @import("commandbuffer.zig").CommandBuffer;
const Mesh = @import("mesh.zig").Mesh;

pub const Pipeline = struct {
    const Self = @This();

    handle: vk.Pipeline,
    layout: vk.PipelineLayout,

    /// shader modules used in this pipeline
    modules: [2]vk.ShaderModule = undefined,

    pub fn init(
        device: Device,
        renderpass: RenderPass,
        descriptor_set_layouts: []const vk.DescriptorSetLayout,
        push_constants: []const vk.PushConstantRange,
        viewport: vk.Viewport,
        scissor: vk.Rect2D,
        wireframe: bool,
        allocator: std.mem.Allocator,
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
            .vertex_binding_description_count = @intCast(u32, Mesh.info.bindings.len),
            .p_vertex_binding_descriptions = @ptrCast(
                [*]const vk.VertexInputBindingDescription,
                &Mesh.info.bindings,
            ),
            .vertex_attribute_description_count = @intCast(u32, Mesh.info.attrs.len),
            .p_vertex_attribute_descriptions = &Mesh.info.attrs,
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
        var stages: [2]vk.PipelineShaderStageCreateInfo = undefined;
        const stage_types = [_]vk.ShaderStageFlags{
            .{ .vertex_bit = true },
            .{ .fragment_bit = true },
        };

        const stage_names = [_][]const u8{
            "builtin.vert",
            "builtin.frag",
        };

        for (self.modules) |*m, i| {
            const data = try loadShader(stage_names[i], allocator);

            m.* = try device.vkd.createShaderModule(device.logical, &.{
                .flags = .{},
                .code_size = data.len,
                .p_code = @ptrCast([*]const u32, @alignCast(4, data)),
            }, null);

            stages[i] = .{
                .flags = .{},
                .stage = stage_types[i],
                .module = m.*,
                .p_name = "main",
                .p_specialization_info = null,
            };

            allocator.free(data);
        }

        const gpci = vk.GraphicsPipelineCreateInfo{
            .flags = .{},
            .stage_count = @intCast(u32, stages.len),
            .p_stages = &stages,
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

    fn loadShader(name: []const u8, alloctor: std.mem.Allocator) ![]u8 {
        // path for assets
        var buf: [512]u8 = undefined;
        const path = try std.fmt.bufPrint(buf[0..], "assets/{s}.spv", .{name});

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
            device.vkd.destroyShaderModule(device.logical, m, null);
        }
        device.vkd.destroyPipeline(device.logical, self.handle, null);
        device.vkd.destroyPipelineLayout(device.logical, self.layout, null);
    }
};
