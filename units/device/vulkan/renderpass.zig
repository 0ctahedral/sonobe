const dispatch_types = @import("dispatch_types.zig");
const BaseDispatch = dispatch_types.BaseDispatch;
const InstanceDispatch = dispatch_types.InstanceDispatch;
const std = @import("std");
const vk = @import("vulkan");
const Device = @import("device.zig").Device;
const Swapchain = @import("swapchain.zig").Swapchain;
const CommandBuffer = @import("commandbuffer.zig").CommandBuffer;
const descs = @import("../resources/descs.zig");

pub const ClearFlags = packed struct {
    color: bool = false,
    depth: bool = false,
    stencil: bool = false,
};

pub const RenderPass = struct {
    handle: vk.RenderPass,

    // TODO: make this a vec4
    clear_color: [4]f32,

    /// depth value
    depth: f32,
    stencil: u32,

    const Self = @This();

    pub fn init(
        device: Device,
        format: vk.Format,
        desc: descs.RenderPassDesc,
    ) !Self {
        // start by making attachments
        // color
        const color_attachment = vk.AttachmentDescription{
            .flags = .{},
            .format = format,
            .samples = .{ .@"1_bit" = true },
            .load_op = if (desc.clear_flags.color) .clear else .load,
            .store_op = .store,
            .stencil_load_op = .dont_care,
            .stencil_store_op = .dont_care,
            // TODO: add prev pass option
            .initial_layout = .@"undefined",
            // TODO: add next pass option
            .final_layout = .present_src_khr,
        };

        const color_attachment_ref = vk.AttachmentReference{
            .attachment = 0,
            .layout = .color_attachment_optimal,
        };

        const depth_attachment = vk.AttachmentDescription{
            .flags = .{},
            .format = device.depth_format,
            .samples = .{ .@"1_bit" = true },
            .load_op = if (desc.clear_flags.depth) .clear else .load,
            .store_op = .store,
            .stencil_load_op = .dont_care,
            .stencil_store_op = .dont_care,
            // TODO: add prev pass option
            .initial_layout = .@"undefined",
            // TODO: add next pass option
            .final_layout = .depth_stencil_attachment_optimal,
        };

        const depth_attachment_ref = vk.AttachmentReference{
            .attachment = 1,
            .layout = .depth_stencil_attachment_optimal,
        };

        const subpass = vk.SubpassDescription{
            .flags = .{},
            .pipeline_bind_point = .graphics,

            .input_attachment_count = 0,
            .p_input_attachments = undefined,

            .color_attachment_count = 1,
            .p_color_attachments = @ptrCast([*]const vk.AttachmentReference, &color_attachment_ref),

            .p_resolve_attachments = null,
            .p_depth_stencil_attachment = &depth_attachment_ref,

            // attachments not used in this subpass but in others
            .preserve_attachment_count = 0,
            .p_preserve_attachments = undefined,
        };

        // TODO: make configurable
        const dependency = vk.SubpassDependency{
            .src_subpass = vk.SUBPASS_EXTERNAL,
            .dst_subpass = 0,
            .src_stage_mask = .{ .color_attachment_output_bit = true },
            .src_access_mask = .{},
            .dst_stage_mask = .{ .color_attachment_output_bit = true },
            .dst_access_mask = .{
                .color_attachment_read_bit = true,
                .color_attachment_write_bit = true,
            },
            .dependency_flags = .{},
        };

        const attachment_descriptions = [_]vk.AttachmentDescription{
            color_attachment,
            depth_attachment,
        };

        const rp = try device.vkd.createRenderPass(device.logical, &.{
            .flags = .{},
            .p_next = null,
            .attachment_count = attachment_descriptions.len,
            .p_attachments = @ptrCast([*]const vk.AttachmentDescription, &attachment_descriptions),
            .subpass_count = 1,
            .p_subpasses = @ptrCast([*]const vk.SubpassDescription, &subpass),
            .dependency_count = 1,
            .p_dependencies = @ptrCast([*]const vk.SubpassDependency, &dependency),
        }, null);

        return Self{
            .handle = rp,
            .clear_color = [_]f32{
                desc.clear_color.x,
                desc.clear_color.y,
                desc.clear_color.z,
                desc.clear_color.w,
            },
            .depth = desc.clear_depth,
            .stencil = desc.clear_stencil,
        };
    }

    pub fn deinit(self: Self, device: Device) void {
        device.vkd.destroyRenderPass(device.logical, self.handle, null);
    }

    pub fn begin(
        self: Self,
        dev: Device,
        command_buffer: *CommandBuffer,
        framebuffer: vk.Framebuffer,
        render_area: vk.Rect2D,
    ) void {
        var clear_values: [2]vk.ClearValue = undefined;
        // color
        clear_values[0] = vk.ClearValue{ .color = .{ .float_32 = self.clear_color } };
        // depth
        clear_values[1] = vk.ClearValue{ .depth_stencil = .{
            .depth = self.depth,
            .stencil = self.stencil,
        } };

        dev.vkd.cmdBeginRenderPass(command_buffer.handle, &.{
            .render_pass = self.handle,
            .framebuffer = framebuffer,
            .render_area = render_area,
            .clear_value_count = clear_values.len,
            .p_clear_values = @ptrCast([*]const vk.ClearValue, &clear_values[0]),
        }, .@"inline");

        command_buffer.*.state = .in_render_pass;
    }

    pub fn end(
        self: Self,
        dev: Device,
        command_buffer: *CommandBuffer,
    ) void {
        _ = self;
        dev.vkd.cmdEndRenderPass(command_buffer.handle);
        command_buffer.*.state = .recording;
    }
};
