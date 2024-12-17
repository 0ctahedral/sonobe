const std = @import("std");
const vk = @import("vulkan");
const Device = @import("device.zig").Device;
// const Buffer = @import("buffer.zig").Buffer;
// const CommandBuffer = @import("commandbuffer.zig").CommandBuffer;
const TextureDesc = @import("Texture.zig").TextureDesc;

handle: vk.Image = .null_handle,
view: vk.ImageView = undefined,

mem: vk.DeviceMemory = .null_handle,

format: vk.Format = .undefined,

width: u32 = 0,
height: u32 = 0,

const Image = @This();
/// image from a managed resource (swapchain)
/// creates an image view and copies the vkImage in
pub fn createView(
    self: *Image,
    device: *const Device,
    format: vk.Format,
    aspect_mask: vk.ImageAspectFlags,
    texture_type: TextureDesc.Type,
) !void {
    const img_type: vk.ImageViewType = switch (texture_type) {
        .@"2d" => .@"2d",
        .cubemap => .cube,
    };
    const info = vk.ImageViewCreateInfo{
        .flags = .{},
        .image = self.handle,
        .view_type = img_type,
        .format = format,
        // TODO: set with config
        .components = .{ .r = .identity, .g = .identity, .b = .identity, .a = .identity },
        // TODO: set with config
        .subresource_range = .{
            .aspect_mask = aspect_mask,
            .level_count = 1,
            .base_mip_level = 0,
            .layer_count = if (texture_type == .cubemap) 6 else 1,
            .base_array_layer = 0,
        },
    };
    self.format = format;
    self.view = try device.dev.createImageView(&info, null);
}

pub fn init(
    device: *const Device,
    width: u32,
    height: u32,
    depth: u32,
    format: vk.Format,
    tiling: vk.ImageTiling,
    usage: vk.ImageUsageFlags,
    mem_flags: vk.MemoryPropertyFlags,
    aspect_mask: vk.ImageAspectFlags,
    texture_type: TextureDesc.Type,
) !Image {
    var self: Image = undefined;

    self.width = width;
    self.height = height;

    const img_type = switch (texture_type) {
        .@"2d", .cubemap => .@"2d",
    };

    const info = vk.ImageCreateInfo{
        .image_type = img_type,
        .flags = .{
            .cube_compatible_bit = texture_type == .cubemap,
        },
        .extent = .{
            .width = width,
            .height = height,
            .depth = depth,
        },
        // TODO: mip mapping
        .mip_levels = 2,
        .array_layers = if (texture_type == .cubemap) 6 else 1,
        .format = format,
        .tiling = tiling,
        .initial_layout = .undefined,
        .usage = usage,
        .samples = .{ .@"1_bit" = true },
        .sharing_mode = .exclusive,
        .queue_family_index_count = 0,
        .p_queue_family_indices = undefined,
    };

    self.handle = try device.dev.createImage(&info, null);

    // get the memory requirements
    const mem_reqs = device.dev.getImageMemoryRequirements(self.handle);
    const mem_idx = try device.dev.findMemoryIndex(mem_reqs.memory_type_bits, mem_flags);

    // allocate memory
    self.mem = try device.dev.allocateMemory(&.{
        .allocation_size = mem_reqs.size,
        .memory_type_index = mem_idx,
    }, null);

    // bind memory
    try device.dev.bindImageMemory(self.handle, self.mem, 0);

    self.format = format;

    try self.createView(device, format, aspect_mask, texture_type);

    return self;
}

// pub fn transitionLayout(
//     self: *Image,
//     device: *Device,
//     old_layout: vk.ImageLayout,
//     new_layout: vk.ImageLayout,
//     cmdbuf: CommandBuffer,
//     texture_type: TextureDesc.Type,
// ) !void {
//     var barrier = vk.ImageMemoryBarrier{
//         .src_access_mask = .{},
//         .dst_access_mask = .{},
//         .src_queue_family_index = device.graphics.?.idx,
//         .dst_queue_family_index = device.graphics.?.idx,
//         .old_layout = old_layout,
//         .new_layout = new_layout,
//         .image = self.handle,
//         .subresource_range = .{
//             .aspect_mask = .{ .color_bit = true },
//             .base_mip_level = 0,
//             .level_count = 1,
//             .base_array_layer = 0,
//             .layer_count = if (texture_type == .cubemap) 6 else 1,
//         },
//     };
//
//     var source_stage = vk.PipelineStageFlags{};
//     var dest_stage = vk.PipelineStageFlags{};
//
//     if (old_layout == .undefined and new_layout == .transfer_dst_optimal) {
//         barrier.src_access_mask = .{};
//         barrier.dst_access_mask = .{ .transfer_write_bit = true };
//
//         source_stage = .{ .top_of_pipe_bit = true };
//         dest_stage = .{ .transfer_bit = true };
//     } else if (old_layout == .transfer_dst_optimal and new_layout == .shader_read_only_optimal) {
//         // for reading into a shader?
//
//         barrier.src_access_mask = .{ .transfer_write_bit = true };
//         barrier.dst_access_mask = .{ .shader_read_bit = true };
//
//         source_stage = .{ .transfer_bit = true };
//         dest_stage = .{ .fragment_shader_bit = true };
//     } else {
//         return error.UnsupportedLayoutTransisiton;
//     }
//
//     device.cmdPipelineBarrier(
//         cmdbuf.handle,
//         source_stage,
//         dest_stage,
//         .{},
//         0,
//         undefined,
//         0,
//         undefined,
//         1,
//         @ptrCast(&barrier),
//     );
// }

// pub fn copyFromBuffer(
//     self: *Image,
//     device: *Device,
//     buffer: Buffer,
//     cmdbuf: CommandBuffer,
//     texture_type: TextureDesc.Type,
//     offset_x: u32,
//     offset_y: u32,
//     extent_x: u32,
//     extent_y: u32,
// ) !void {
//     const bic = vk.BufferImageCopy{
//         .buffer_offset = 0,
//         .buffer_row_length = 0,
//         .buffer_image_height = 0,
//         .image_subresource = .{
//             .aspect_mask = .{ .color_bit = true },
//             .mip_level = 0,
//             .layer_count = if (texture_type == .cubemap) 6 else 1,
//             .base_array_layer = 0,
//         },
//         .image_offset = .{ .x = @intCast(offset_x), .y = @intCast(offset_y), .z = 0 },
//         .image_extent = .{
//             .width = extent_x,
//             .height = extent_y,
//             .depth = 1,
//         },
//     };
//
//     device.cmdCopyBufferToImage(cmdbuf.handle, buffer.handle, self.handle, .transfer_dst_optimal, 1, @ptrCast(&bic));
// }

pub fn deinit(self: *Image, device: *const Device) void {
    device.dev.destroyImageView(self.view, null);
    self.view = .null_handle;
    // if this has memory then we know it is an image we created
    if (self.mem != .null_handle) {
        device.dev.freeMemory(self.mem, null);
        self.mem = .null_handle;
        device.dev.destroyImage(self.handle, null);
        self.handle = .null_handle;
    }
}
