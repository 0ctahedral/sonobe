const std = @import("std");
const vk = @import("vulkan");
const dispatch_types = @import("dispatch_types.zig");
const InstanceDispatch = dispatch_types.InstanceDispatch;
const Device = @import("device.zig").Device;

pub const Image = struct {
    handle: vk.Image,
    view: vk.ImageView = undefined,

    /// is this image's handle managed elsewhere?
    managed: bool = true,

    const Self = @This();
    /// image from a managed resource (swapchain)
    /// creates an image view and copies the vkImage in
    pub fn createView(
        self: *Self,
        device: Device,
        format: vk.Format,
        aspect_mask: vk.ImageAspectFlags,
    ) !void {
        const info = vk.ImageViewCreateInfo{
            .flags = .{},
            .image = self.handle,
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
                .aspect_mask = aspect_mask,
                .level_count = 1,
                .base_mip_level = 0,
                .layer_count = 1,
                .base_array_layer = 0,
            },
        };
        self.view = try device.vkd.createImageView(device.logical, &info, null);
    }

    //pub fn init(
    //    device: Device,
    //    img_type: vk.ImageType,
    //    extend: vk.Extent2D,
    //    format: vk.Format,
    //    tiling: vk.ImageTiling,
    //    usage: vk.ImageUsageFlags,
    //    mem_flags: vk.MemoryPropertyFlags,
    //    aspect_mask: vk.ImageAspectFlags,
    //) Self {
    //    return Self{
    //        .handle = image,
    //        .view = view,
    //        .managed = false,
    //    };
    //}

    pub fn deinit(self: *Self, device: Device) void {
        device.vkd.destroyImageView(device.logical, self.view, null);
        // TODO: add image destruction if not managed
        //if (!self.managed) { }
    }
};
