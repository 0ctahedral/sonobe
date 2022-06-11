const std = @import("std");
const vk = @import("vulkan");
const Device = @import("device.zig").Device;
const Image = @import("image.zig").Image;
const Buffer = @import("buffer.zig").Buffer;
const CommandBuffer = @import("commandbuffer.zig").CommandBuffer;

pub const TextureMap = struct {
    /// corresponding texture
    /// TODO: might end up being a pointer?
    texture: *Texture = undefined,

    /// filter type for minifying
    min_filter: vk.Filter = .linear,
    /// filter type for magnifiying
    mag_filter: vk.Filter = .linear,

    /// how to repeat the texture in the x direction
    repeat_u: vk.SamplerAddressMode = .repeat,
    /// how to repeat the texture in the y direction
    repeat_v: vk.SamplerAddressMode = .repeat,
    /// how to repeat the texture in the z direction
    repeat_w: vk.SamplerAddressMode = .repeat,

    /// sampler for this texture
    sampler: vk.Sampler = .null_handle,

    const Self = @This();

    pub fn init(
        device: Device,
        texture: *Texture,
        // TODO: configurable
    ) !Self {
        var self = Self{};

        const sci = vk.SamplerCreateInfo{
            .flags = .{},
            .mag_filter = .linear,
            .min_filter = .linear,
            .address_mode_u = self.repeat_u,
            .address_mode_v = self.repeat_v,
            .address_mode_w = self.repeat_w,
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
        self.texture = texture;

        return self;
    }

    pub fn deinit(self: *Self, device: Device) void {
        device.vkd.destroySampler(device.logical, self.sampler, null);
    }
};

/// An image we read and write from
pub const Texture = struct {
    image: Image = .{},

    flags: Flags = .{},

    const Flags = packed struct {
        /// is this texture be transparent?
        transparent: bool = false,
        /// can this texture be written to?
        writable: bool = false,
        /// is this owned externally?
        owned: bool = false,
    };

    const Self = @This();

    pub fn init(
        device: Device,
        width: u32,
        height: u32,
        channels: u32,
        flags: Flags,
        data: []const u8,
    ) !Self {
        var self: Self = undefined;

        self.flags = flags;

        const img_format = switch (channels) {
            1 => vk.Format.r8_unorm,
            2 => vk.Format.r8g8_unorm,
            3 => vk.Format.r8g8b8_unorm,
            4 => vk.Format.r8g8b8a8_unorm,
            else => return error.InvalidNumberOfChannels,
        };

        self.image = try Image.init(
            device,
            .@"2d",
            width,
            height,
            img_format,
            .optimal,
            .{
                // might be different for nonwritable?
                .transfer_src_bit = true,
                .transfer_dst_bit = true,
                .sampled_bit = true,
                .color_attachment_bit = true,
            },
            .{ .device_local_bit = true },
            .{ .color_bit = true },
        );

        const image_size = width * height * channels;
        try self.write(device, 0, image_size, data);

        return self;
    }

    // TODO: For writeable textues

    pub fn resize(
        self: *Self,
        device: Device,
        new_width: u32,
        new_height: u32,
    ) !void {
        const img_format = self.image.format;
        // destroy old image and create new
        self.image.deinit(device);
        self.image = try Image.init(
            device,
            .@"2d",
            new_width,
            new_height,
            img_format,
            .optimal,
            .{
                // might be different for nonwritable?
                .transfer_src_bit = true,
                .transfer_dst_bit = true,
                .sampled_bit = true,
                .color_attachment_bit = true,
            },
            .{ .device_local_bit = true },
            .{ .color_bit = true },
        );
    }

    pub fn write(
        self: *Self,
        device: Device,
        offset: u32,
        size: u32,
        data: []const u8,
    ) !void {
        var staging = try Buffer.init(device, size, .{ .transfer_src_bit = true }, .{
            .host_visible_bit = true,
            .host_coherent_bit = true,
        }, true);
        defer staging.deinit(device);

        try staging.load(device, u8, data, offset);

        var cmdbuf = try CommandBuffer.beginSingleUse(device, device.command_pool);

        try self.image.transitionLayout(device, .@"undefined", .transfer_dst_optimal, cmdbuf);
        try self.image.copyFromBuffer(device, staging, cmdbuf);
        try self.image.transitionLayout(device, .transfer_dst_optimal, .shader_read_only_optimal, cmdbuf);

        try cmdbuf.endSingleUse(device, device.command_pool, device.graphics.?.handle);
    }

    pub fn deinit(self: *Self, device: Device) void {
        self.image.deinit(device);
    }
};
