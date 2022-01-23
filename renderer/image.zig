const std = @import("std");
const vk = @import("vulkan");
const dispatch_types = @import("dispatch_types.zig");
const InstanceDispatch = dispatch_types.InstanceDispatch;
const Device = @import("device.zig").Device;

pub const Image = struct {
    handle: vk.Image,
    view: vk.ImageView,

    /// is this image's handle managed elsewhere?
    managed: bool,

    const Self = @This();
    /// image from a managed resource (swapchain)
    /// creates an image view and copies the vkImage in
    pub fn initManaged(
        device: Device,
        image: vk.Image,
        format: vk.Format
    ) !Self {
        const view = try device.vkd.createImageView(device.logical, &.{
            .flags = .{},
            .image = image,
            .view_type = .@"2d",
            .format = format,
            // TODO: set with config
            .components = .{
                .r = .identity,
                .g = .identity,
                .b = .identity,
                .a = .identity
            },
            // TODO: set with config
            .subresource_range = .{
                .aspect_mask = .{ .color_bit = true },
                .level_count = 1,
                .base_mip_level = 0,
                .layer_count = 1,
                .base_array_layer = 0,
            },
        },
        null
        );

        return Self{
            .handle = image,
            .view = view,
            .managed = true,
        };
    }

    pub fn deinit(self: Self, device: Device) void {
        device.vkd.destroyImageView(device.logical, self.view, null);
        // TODO: add image destruction if not managed
        //if (!self.managed) { }
    }
};
