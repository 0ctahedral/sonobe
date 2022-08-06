const std = @import("std");
const vk = @import("vulkan");
const types = @import("../rendertypes.zig");
const SamplerDesc = @import("../rendertypes.zig").SamplerDesc;
const Device = @import("device.zig").Device;
const Image = @import("image.zig").Image;
const Buffer = @import("buffer.zig").Buffer;
const CommandBuffer = @import("commandbuffer.zig").CommandBuffer;

pub const Sampler = struct {
    const Self = @This();

    /// handle to the sampler
    handle: vk.Sampler = .null_handle,

    pub fn init(
        device: Device,
        desc: SamplerDesc,
    ) !Self {
        var self = Self{};

        const Config = struct {
            filter: vk.Filter,
            mipmap_mode: vk.SamplerMipmapMode,
        };

        const mip_filter: Config = switch (desc.filter) {
            .nearest => .{ .filter = .nearest, .mipmap_mode = .nearest },
            .bilinear => .{ .filter = .linear, .mipmap_mode = .nearest },
            .trilinear => .{ .filter = .linear, .mipmap_mode = .linear },
            .anisotropic => .{ .filter = .linear, .mipmap_mode = .linear },
        };

        const repeat: vk.SamplerAddressMode = switch (desc.repeat) {
            .wrap => .repeat,
            .clamp => .clamp_to_edge,
        };

        const compare_op: vk.CompareOp = switch (desc.compare) {
            .never => .never,
            .less => .less,
            .greater => .greater,
            .less_eq => .less_or_equal,
            .greater_eq => .greater_or_equal,
        };

        const sci = vk.SamplerCreateInfo{
            .flags = .{},
            .mag_filter = mip_filter.filter,
            .min_filter = mip_filter.filter,
            .address_mode_u = repeat,
            .address_mode_v = repeat,
            .address_mode_w = repeat,
            .mipmap_mode = mip_filter.mipmap_mode,
            .mip_lod_bias = 0,
            .anisotropy_enable = if (desc.filter == .anisotropic) vk.TRUE else vk.FALSE,
            .max_anisotropy = 16,
            .compare_enable = if (desc.compare == .never) vk.FALSE else vk.TRUE,
            .compare_op = compare_op,
            .min_lod = 0,
            .max_lod = 0,
            .border_color = vk.BorderColor.float_opaque_black,
            .unnormalized_coordinates = vk.FALSE,
        };

        self.handle = try device.vkd.createSampler(device.logical, &sci, null);

        return self;
    }

    pub fn deinit(self: *Self, device: Device) void {
        device.vkd.destroySampler(device.logical, self.handle, null);
    }
};

/// An image we read and write from
pub const Texture = struct {
    image: Image = .{},
    desc: types.TextureDesc,

    const Self = @This();

    pub fn init(
        device: Device,
        desc: types.TextureDesc,
        data: []const u8,
    ) !Self {
        var self: Self = undefined;
        self.desc = desc;

        const img_format = switch (desc.channels) {
            1 => vk.Format.r8_unorm,
            2 => vk.Format.r8g8_unorm,
            3 => vk.Format.r8g8b8_unorm,
            4 => vk.Format.r8g8b8a8_unorm,
            else => return error.InvalidNumberOfChannels,
        };

        self.image = try Image.init(
            device,
            desc.width,
            desc.height,
            desc.depth,
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
            desc.texture_type,
        );

        // const image_size = desc.width * desc.height * @as(u32, desc.channels);
        try self.write(device, 0, data);

        return self;
    }

    pub fn resize(
        self: *Self,
        device: Device,
        new_width: u32,
        new_height: u32,
        new_depth: u32,
    ) !void {
        const img_format = self.image.format;
        // destroy old image and create new
        self.image.deinit(device);
        self.image = try Image.init(
            device,
            new_width,
            new_height,
            new_depth,
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
            self.desc.texture_type,
        );
    }

    pub fn write(
        self: *Self,
        device: Device,
        offset: u32,
        data: []const u8,
    ) !void {
        return self.writeRegion(device, offset, data, 0, 0, self.image.width, self.image.height);
    }

    pub fn writeRegion(
        self: *Self,
        device: Device,
        offset: u32,
        data: []const u8,
        offset_x: u32,
        offset_y: u32,
        extent_x: u32,
        extent_y: u32,
    ) !void {
        var staging = try Buffer.init(device, data.len, .{ .transfer_src_bit = true }, .{
            .host_visible_bit = true,
            .host_coherent_bit = true,
        }, true);
        defer staging.deinit(device);

        try staging.load(device, u8, data, offset);

        var cmdbuf = try CommandBuffer.beginSingleUse(device, device.command_pool);

        try self.image.transitionLayout(device, .@"undefined", .transfer_dst_optimal, cmdbuf, self.desc.texture_type);
        try self.image.copyFromBuffer(
            device,
            staging,
            cmdbuf,
            self.desc.texture_type,
            offset_x,
            offset_y,
            extent_x,
            extent_y,
        );
        try self.image.transitionLayout(device, .transfer_dst_optimal, .shader_read_only_optimal, cmdbuf, self.desc.texture_type);

        try cmdbuf.endSingleUse(device, device.command_pool, device.graphics.?.handle);
    }

    pub fn deinit(self: *Self, device: Device) void {
        self.image.deinit(device);
    }
};
