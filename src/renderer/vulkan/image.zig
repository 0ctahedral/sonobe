const std = @import("std");
const vk = @import("vulkan");
const dispatch_types = @import("dispatch_types.zig");
const InstanceDispatch = dispatch_types.InstanceDispatch;
const Device = @import("device.zig").Device;
const Buffer = @import("buffer.zig").Buffer;
const CommandBuffer = @import("commandbuffer.zig").CommandBuffer;

pub const Image = struct {
    handle: vk.Image = .null_handle,
    view: vk.ImageView = undefined,

    mem: vk.DeviceMemory = .null_handle,

    format: vk.Format = .@"undefined",

    width: u32 = 0,
    height: u32 = 0,

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
            .components = .{ .r = .identity, .g = .identity, .b = .identity, .a = .identity },
            // TODO: set with config
            .subresource_range = .{
                .aspect_mask = aspect_mask,
                .level_count = 1,
                .base_mip_level = 0,
                .layer_count = 1,
                .base_array_layer = 0,
            },
        };
        self.format = format;
        self.view = try device.vkd.createImageView(device.logical, &info, null);
    }

    pub fn init(
        device: Device,
        img_type: vk.ImageType,
        width: u32,
        height: u32,
        format: vk.Format,
        tiling: vk.ImageTiling,
        usage: vk.ImageUsageFlags,
        mem_flags: vk.MemoryPropertyFlags,
        aspect_mask: vk.ImageAspectFlags,
    ) !Self {
        var self: Self = undefined;

        self.width = width;
        self.height = height;

        const info = vk.ImageCreateInfo{
            .image_type = img_type,
            .flags = .{},
            .extent = .{
                .width = width,
                .height = height,
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

        self.format = format;

        try self.createView(device, format, aspect_mask);

        return self;
    }

    pub fn transitionLayout(
        self: *Self,
        device: Device,
        old_layout: vk.ImageLayout,
        new_layout: vk.ImageLayout,
        cmdbuf: CommandBuffer,
    ) !void {
        var barrier = vk.ImageMemoryBarrier{
            .src_access_mask = .{},
            .dst_access_mask = .{},
            .src_queue_family_index = device.graphics.?.idx,
            .dst_queue_family_index = device.graphics.?.idx,
            .old_layout = old_layout,
            .new_layout = new_layout,
            .image = self.handle,
            .subresource_range = .{
                .aspect_mask = .{ .color_bit = true },
                .base_mip_level = 0,
                .level_count = 1,
                .base_array_layer = 0,
                .layer_count = 1,
            },
        };

        var source_stage = vk.PipelineStageFlags{};
        var dest_stage = vk.PipelineStageFlags{};

        if (old_layout == .@"undefined" and new_layout == .transfer_dst_optimal) {
            barrier.src_access_mask = .{};
            barrier.dst_access_mask = .{ .transfer_write_bit = true };

            source_stage = .{ .top_of_pipe_bit = true };
            dest_stage = .{ .transfer_bit = true };
        } else if (old_layout == .transfer_dst_optimal and new_layout == .shader_read_only_optimal) {
            // for reading into a shader?

            barrier.src_access_mask = .{ .transfer_write_bit = true };
            barrier.dst_access_mask = .{ .shader_read_bit = true };

            source_stage = .{ .transfer_bit = true };
            dest_stage = .{ .fragment_shader_bit = true };
        } else {
            return error.UnsupportedLayoutTransisiton;
        }

        device.vkd.cmdPipelineBarrier(
            cmdbuf.handle,
            source_stage,
            dest_stage,
            .{},
            0,
            undefined,
            0,
            undefined,
            1,
            @ptrCast([*]vk.ImageMemoryBarrier, &barrier),
        );
    }

    pub fn copyFromBuffer(
        self: *Self,
        device: Device,
        buffer: Buffer,
        cmdbuf: CommandBuffer,
    ) !void {
        std.log.debug("copying width: {} height: {}", .{ self.width, self.height });
        const bic = vk.BufferImageCopy{
            .buffer_offset = 0,
            .buffer_row_length = 0,
            .buffer_image_height = 0,
            .image_subresource = .{
                .aspect_mask = .{ .color_bit = true },
                .mip_level = 0,
                .layer_count = 1,
                .base_array_layer = 0,
            },
            .image_offset = .{ .x = 0, .y = 0, .z = 0 },
            .image_extent = .{
                .width = self.width,
                .height = self.height,
                .depth = 1,
            },
        };

        device.vkd.cmdCopyBufferToImage(cmdbuf.handle, buffer.handle, self.handle, .transfer_dst_optimal, 1, @ptrCast([*]const vk.BufferImageCopy, &bic));
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
