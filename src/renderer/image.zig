const std = @import("std");
const vk = @import("vulkan");
const dispatch_types = @import("dispatch_types.zig");
const InstanceDispatch = dispatch_types.InstanceDispatch;
const Device = @import("device.zig").Device;

pub const Image = struct {
    handle: vk.Image,
    view: vk.ImageView = undefined,

    mem: vk.DeviceMemory = .null_handle,

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

    pub fn init(
        device: Device,
        img_type: vk.ImageType,
        extent: vk.Extent2D,
        format: vk.Format,
        tiling: vk.ImageTiling,
        usage: vk.ImageUsageFlags,
        mem_flags: vk.MemoryPropertyFlags,
        aspect_mask: vk.ImageAspectFlags,
    ) !Self {
        var self: Self = undefined;

        const info = vk.ImageCreateInfo{
            .image_type = img_type,
            .flags = .{},
            .extent = .{
                .width = extent.width,
                .height = extent.height,
                // TODO: configurable
                .depth = 1,
            },
            // TODO: mip mapping
            .mip_levels = 4,
            .array_layers = 1,
            .format = format,
            .tiling = tiling,
            .initial_layout = .@"undefined",
            .usage = usage,
            .samples = .{ .@"1_bit" = true },
            .sharing_mode = .exclusive,
            .queue_family_index_count = 0,
            .p_queue_family_indices = undefined,

        };


        self.handle = try device.vkd.createImage(device.logical, &info, null);

        // get the memory requirements
        const mem_reqs = device.vkd.getImageMemoryRequirements(device.logical, self.handle);
        const mem_idx = try device.findMemoryIndex(mem_reqs.memory_type_bits, mem_flags);

        // allocate memory
        self.mem = try device.vkd.allocateMemory(device.logical, &.{
            .allocation_size = mem_reqs.size,
            .memory_type_index = mem_idx,
        }, null);

        // bind memory
        try device.vkd.bindImageMemory(device.logical, self.handle, self.mem, 0);

        try self.createView(device, format, aspect_mask);

        return self;
    }

    pub fn deinit(self: *Self, device: Device) void {
        device.vkd.destroyImageView(device.logical, self.view, null);
        self.view = .null_handle;
        // if this has memory then we know it is an image we created
        if (self.mem != .null_handle) {
            device.vkd.freeMemory(device.logical, self.mem, null);
            self.mem = .null_handle;
            device.vkd.destroyImage(device.logical, self.handle, null);
            self.handle = .null_handle;
        }
    }
};
