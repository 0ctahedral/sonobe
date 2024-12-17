const vk = @import("vulkan");
const Image = @import("Image.zig");
const Device = @import("device.zig").Device;

pub const TextureDesc = struct {
    pub const Type = enum {
        @"2d",
        cubemap,
    };
    width: u32,
    height: u32,
    depth: u32 = 1,
    channels: u8,
    flags: packed struct {
        /// is this texture be transparent?
        transparent: bool = false,
        /// can this texture be written to?
        writable: bool = false,
    },
    texture_type: Type,
};

image: Image = .{},
desc: TextureDesc,

pub const Texture = @This();

pub fn init(
    device: *Device,
    desc: TextureDesc,
    data: []const u8,
) !Texture {
    var self: Texture = try initEmpty(device, desc);
    try self.write(device, 0, data);
    return self;
}

pub fn deinit(self: *Texture, device: *Device) void {
    self.image.deinit(device);
}

pub fn initEmpty(
    device: *Device,
    desc: TextureDesc,
) !Texture {
    var self: Texture = undefined;
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

    return self;
}

pub fn resize(
    self: *Texture,
    device: *Device,
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

// pub fn write(
//     self: *Texture,
//     device: *Device,
//     offset: u32,
//     data: []const u8,
// ) !void {
//     return self.writeRegion(device, offset, data, 0, 0, self.image.width, self.image.height);
// }
//
// pub fn writeRegion(
//     self: *Texture,
//     device: *Device,
//     offset: u32,
//     data: []const u8,
//     offset_x: u32,
//     offset_y: u32,
//     extent_x: u32,
//     extent_y: u32,
// ) !void {
//     var staging = try Buffer.init(device, data.len, .{ .transfer_src_bit = true }, .{
//         .host_visible_bit = true,
//         .host_coherent_bit = true,
//     }, true);
//     defer staging.deinit(device);
//
//     try staging.load(device, u8, data, offset);
//
//     var cmdbuf = try CommandBuffer.beginSingleUse(device, device.command_pool);
//
//     try self.image.transitionLayout(device, .undefined, .transfer_dst_optimal, cmdbuf, self.desc.texture_type);
//     try self.image.copyFromBuffer(
//         device,
//         staging,
//         cmdbuf,
//         self.desc.texture_type,
//         offset_x,
//         offset_y,
//         extent_x,
//         extent_y,
//     );
//     try self.image.transitionLayout(device, .transfer_dst_optimal, .shader_read_only_optimal, cmdbuf, self.desc.texture_type);
//
//     try cmdbuf.endSingleUse(device, device.command_pool, device.graphics.?.handle);
// }
