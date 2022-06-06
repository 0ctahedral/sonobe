
const std = @import("std");
const vk = @import("vulkan");
const Device = @import("device.zig").Device;
const Image = @import("image.zig").Image;
const Buffer = @import("buffer.zig").Buffer;
const CommandBuffer = @import("commandbuffer.zig").CommandBuffer;

/// An image we read and write from
pub const Texture = struct {
    image: Image,
    sampler: vk.Sampler = .null_handle,

    const Self = @This();

    pub fn init(
        device: Device,
        width: u32,
        height: u32,
        channels: u32,
        data: []const u8,
    ) !Self {
        var self: Self = undefined;

        // Assume 8 bits per channel
        const img_format = vk.Format.r8g8b8a8_unorm;
        const image_size = width * height * channels;

        var staging = try Buffer.init(
            device,
            image_size,
            .{ .transfer_src_bit = true },
            .{
                .host_visible_bit = true,
                .host_coherent_bit = true,
            }, true);
        
        try staging.load(device, u8, data, 0);


        self.image = try Image.init(
            device,
            .@"2d",
            width,
            height,
            img_format,
            .optimal,
            .{
                .transfer_src_bit = true,
                .transfer_dst_bit = true,
                .sampled_bit = true,
                .color_attachment_bit = true,
            },
            .{ .device_local_bit = true },
            .{ .color_bit = true },
        );

        std.log.debug("self.image width: {} height: {}", .{self.image.width, self.image.height});

        var cmdbuf = try CommandBuffer.beginSingleUse(device, device.command_pool);

        try self.image.transitionLayout(device, .@"undefined", .transfer_dst_optimal, cmdbuf);
        try self.image.copyFromBuffer(device, staging, cmdbuf);
        try self.image.transitionLayout(device, .transfer_dst_optimal, .shader_read_only_optimal, cmdbuf);

        try cmdbuf.endSingleUse(device, device.command_pool, device.graphics.?.handle);

        const sci = vk.SamplerCreateInfo{
            .flags = .{},
            .mag_filter = .linear,
            .min_filter = .linear,
            .address_mode_u = vk.SamplerAddressMode.repeat,
            .address_mode_v = vk.SamplerAddressMode.repeat,
            .address_mode_w = vk.SamplerAddressMode.repeat,
            .mipmap_mode = vk.SamplerMipmapMode.linear,
            .mip_lod_bias = 0,
            .anisotropy_enable = vk.TRUE,
            .max_anisotropy = 16,
            .compare_enable = vk.FALSE,
            .compare_op = vk.CompareOp.always,
            .min_lod = 0,
            .max_lod = 0,
            .border_color = vk.BorderColor.float_opaque_black,
            .unnormalized_coordinates = vk.FALSE,
        };

        self.sampler = try device.vkd.createSampler(device.logical, &sci, null); 


        staging.deinit(device);

        return self;
    }

    pub fn deinit(self: *Self, device: Device) void {
        // device.vkd.deviceWaitIdle(device.logical); 

        device.vkd.destroySampler(device.logical, self.sampler, null);
        self.image.deinit(device);
    }
};
