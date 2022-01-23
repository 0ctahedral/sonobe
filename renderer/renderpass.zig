const dispatch_types = @import("dispatch_types.zig");
const BaseDispatch = dispatch_types.BaseDispatch;
const InstanceDispatch = dispatch_types.InstanceDispatch;
const std = @import("std");
const vk = @import("vulkan");
const Device = @import("device.zig").Device;
const Swapchain = @import("swapchain.zig").Swapchain;

pub const ClearFlags = packed struct {
    color: bool = false,
    depth: bool = false,
    stencil: bool = false,
};

pub const RenderPass = struct {
    handle: vk.RenderPass,


    /// extents of the render area
    /// aka start and end position
    //TODO: make this a vec4
    //render_area: [4]f32,

    //TODO: make this a vec4
    //clear_color: [4]f32,

    /// depth value
    //depth: f32,

    const Self = @This();

    pub fn init(
        swapchain: Swapchain,
        device: Device,
        clear_flags: ClearFlags,
    ) !Self  {
        // start by making attachments
        // color
        const color_attachment = vk.AttachmentDescription{
            .flags = .{},
            .format = swapchain.surface_format.format,
            .samples = .{ .@"1_bit" = true },
            .load_op = if (clear_flags.color) .clear else .load,
            .store_op = .store,
            .stencil_load_op = .dont_care,
            .stencil_store_op = .dont_care,
            // TODO: add prev pass option
            .initial_layout = .@"undefined",
            // TODO: add next pass option
            .final_layout = .present_src_khr,
        };
        _ = color_attachment;

        const color_attachment_ref = vk.AttachmentReference{
            .attachment = 0,
            .layout = .color_attachment_optimal,
        };

        // TODO: depth
        
        const subpass = vk.SubpassDescription{
            .flags = .{},
            .pipeline_bind_point = .graphics,

            .input_attachment_count = 0,
            .p_input_attachments = undefined,

            .color_attachment_count = 1,
            .p_color_attachments = @ptrCast([*]const vk.AttachmentReference, &color_attachment_ref),

            // TODO
            .p_resolve_attachments = null,
            .p_depth_stencil_attachment = null,

            // attachments not used in this subpass but in others
            .preserve_attachment_count = 0,
            .p_preserve_attachments = undefined,
        };

        // todo
        //const dependency = vk.SubpassDependency{
        //    .src_subpass = .{ .external },
        //    .dest_subpass = .{},
        //    .src_stage_mask = .{}
        //};
        //

        const rp = try device.vkd.createRenderPass(device.logical, &.{
                .flags = .{},
                .attachment_count = 1,
                .p_attachments = @ptrCast([*]const vk.AttachmentDescription, &color_attachment),
                .subpass_count = 1,
                .p_subpasses = @ptrCast([*]const vk.SubpassDescription, &subpass),
                .dependency_count = 0,
                .p_dependencies = undefined,
            }, null);

        return Self{
            .handle = rp,
        };
    }

    pub fn deinit(self: Self, device: Device) void {
        device.vkd.destroyRenderPass(device.logical, self.handle, null);
    }

    pub fn begin(self: Self) void {

    }

    pub fn end(self: Self) void {

    }
};
