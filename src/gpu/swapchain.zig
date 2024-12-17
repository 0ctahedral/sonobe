const std = @import("std");
const vk = @import("vulkan");
const gpu = @import("../gpu.zig");
const log = gpu.log.sub("swapchain");
const Instance = gpu.Instance;
const Device = @import("device.zig").Device;
const Image = @import("Image.zig");

pub const Swapchain = @This();

const SwapImage = struct {
    // NOTE: don't need a whole texture, plus we'll add some extra stuff to track later

    handle: vk.Image,
    view: vk.ImageView,

    // image_acquired: vk.Semaphore,
    // render_finished: vk.Semaphore,
    // frame_fence: vk.Fence,

    pub fn init(device: *Device, handle: vk.Image, format: vk.Format) !SwapImage {
        const img_type: vk.ImageViewType = .@"2d";
        const info = vk.ImageViewCreateInfo{
            .flags = .{},
            .image = handle,
            .view_type = img_type,
            .format = format,
            // TODO: set with config
            .components = .{ .r = .identity, .g = .identity, .b = .identity, .a = .identity },
            // TODO: set with config
            .subresource_range = .{
                .aspect_mask = .{.color_bit = true},
                .level_count = 1,
                .base_mip_level = 0,
                .layer_count = 1,
                .base_array_layer = 0,
            },
        };

        return .{
            .handle = handle,
            .view = try device.dev.createImageView(&info, null),
        };
    }

    pub fn deinit(self: *SwapImage, device: *Device) void {
        device.dev.destroyImageView(self.view, null);
    }
};

device: *Device,
allocator: std.mem.Allocator,

handle: vk.SwapchainKHR = .null_handle,
extent: vk.Extent2D = .{ .width = 0, .height = 0},
surface_format: vk.SurfaceFormatKHR = undefined,
// defaults to fifo which all devices support
present_mode: vk.PresentModeKHR = .fifo_khr,

swap_imgs: []SwapImage = undefined,


/// initialize/create a swapchian object
pub fn init(
    instance: Instance,
    device: *Device,
    surface: vk.SurfaceKHR,
    w: u32,
    h: u32,
    allocator: std.mem.Allocator,
) !Swapchain {
    var self: Swapchain = .{
        .device = device,
        .allocator = allocator,
    };
    try self.create(instance, device, surface, w, h, false);
    return self;
}

/// shutdown a swapchian object
pub fn deinit(self: *Swapchain) void {
    self.destroy();
    self.device.dev.destroySwapchainKHR(self.handle, null);
    self.allocator.free(self.swap_imgs);
}

/// create our swapchain
fn create(
    self: *Swapchain,
    instance: Instance,
    device: *Device,
    surface: vk.SurfaceKHR,
    w: u32,
    h: u32,
    is_recreate: bool,
) !void {
    const sub = log.sub("create");
    sub.info("{s} swapchain width", .{if (is_recreate) "recreating" else "creating"});

    self.extent = vk.Extent2D{ .width = w, .height = h };

    // find the format
    const preferred_format = vk.SurfaceFormatKHR{
        .format = .b8g8r8a8_srgb,
        .color_space = .srgb_nonlinear_khr,
    };
    var surface_formats: [32]vk.SurfaceFormatKHR = undefined;
    var surf_count: u32 = 0;
    _ = try instance.getPhysicalDeviceSurfaceFormatsKHR(device.pdev, surface, &surf_count, surface_formats[0..]);

    self.surface_format = preferred_format;

    for (surface_formats[0..surf_count], 0..) |sfmt, i| {
        self.surface_format = sfmt;
        log.debug("fmt {}: {}", .{ i, sfmt });
        if (std.meta.eql(sfmt, preferred_format)) {
            break;
        }
    }

    // find present mode
    var present_modes: [32]vk.PresentModeKHR = undefined;
    _ = try instance.getPhysicalDeviceSurfacePresentModesKHR(device.pdev, surface, &surf_count, present_modes[0..]);

    for (present_modes[0..surf_count]) |mode| {
        // if we can get mailbox that's ideal
        if (mode == .mailbox_khr) {
            self.present_mode = mode;
            break;
        }
    }

    sub.info("chosen present mode: {}", .{self.present_mode});

    // get the actual extent of the window
    const caps = try instance.getPhysicalDeviceSurfaceCapabilitiesKHR(device.pdev, surface);

    self.extent.width = std.math.clamp(self.extent.width, caps.min_image_extent.width, caps.max_image_extent.width);
    self.extent.height = std.math.clamp(self.extent.height, caps.min_image_extent.height, caps.max_image_extent.height);

    sub.debug("swapchain extent: {}", .{self.extent});

    if (self.extent.width == 0 or self.extent.height == 0) {
        return error.InvalidSurfaceDimensions;
    }

    // get the image count
    var min_imgs = caps.min_image_count + 1;
    if (caps.max_image_count > 0) {
        min_imgs = @min(min_imgs, caps.max_image_count);
    }
    min_imgs = @min(min_imgs, 3);

    const qfi = [_]u32{ device.graphics.?.family, device.present.?.family };
    const sharing_mode: vk.SharingMode = if (device.graphics.?.family == device.present.?.family) .exclusive else .concurrent;

    const old_handle = self.handle;

    // create the handle
    self.handle = try device.dev.createSwapchainKHR(&.{
        .flags = .{},
        .surface = surface,
        .min_image_count = min_imgs,
        .image_format = self.surface_format.format,
        .image_color_space = self.surface_format.color_space,
        .image_extent = self.extent,
        // multiple for vr?
        .image_array_layers = 1,
        .image_usage = .{ .color_attachment_bit = true },
        .image_sharing_mode = sharing_mode,
        .queue_family_index_count = qfi.len,
        .p_queue_family_indices = &qfi,
        .pre_transform = caps.current_transform,
        .composite_alpha = .{ .opaque_bit_khr = true },
        .present_mode = self.present_mode,
        .clipped = vk.TRUE,
        .old_swapchain = old_handle,
    }, null);

    if (old_handle != .null_handle) {
        sub.info("destroying old handle: {}", .{old_handle});
        device.dev.destroySwapchainKHR(old_handle, null);
    }

    // make the images and views
    var img_count: u32 = 0;
    var imgs: [8]vk.Image = undefined;
    _ = try device.dev.getSwapchainImagesKHR(self.handle, &img_count, null);
    sub.debug("image img_count: {}", .{img_count});
    _ = try device.dev.getSwapchainImagesKHR(self.handle, &img_count, imgs[0..]);

    if (is_recreate) {
        for (self.swap_imgs) |*img| {
            img.deinit(device);
        }
    } else {
        self.swap_imgs = try self.allocator.alloc(SwapImage, img_count);
    }

    // update the swap images
    for (imgs[0..img_count], 0..) |img, i| {
        self.swap_imgs[i] = try SwapImage.init(self.device, img, self.surface_format.format);
    }
}

/// destroy our swapchain
fn destroy(self: *Swapchain) void {
    log.info("destroying swapchain", .{});
    log.debug("waiting for device idle", .{});
    self.device.dev.deviceWaitIdle() catch {
        unreachable;
    };

    for (self.swap_imgs) |*img| {
        img.deinit(self.device);
    }
}

pub fn recreate(self: *Swapchain, instance: Instance, surface: vk.SurfaceKHR, w: u32, h: u32) !void {
    try self.create(instance, surface, w, h, true);
}

// /// present an image to the swapchain
// pub fn present(
//     self: Swapchain,
//     present_queue: Queue,
//     render_complete: Semaphore,
//     idx: u32,
// ) !void {
//     const result = try self.device.dev.queuePresentKHR(present_queue.handle, &.{
//         .wait_semaphore_count = 1,
//         .p_wait_semaphores = render_complete.ptr(),
//         .swapchain_count = 1,
//         .p_swapchains = @ptrCast(&self.handle),
//         .p_image_indices = @ptrCast(&idx),
//         .p_results = null,
//     });
//
//     switch (result) {
//         .suboptimal_khr, .success => {},
//         else => unreachable,
//     }
// }
//
// pub fn acquireNext(
//     self: Swapchain,
//     semaphore: Semaphore,
//     fence: Fence,
// ) !u32 {
//     const result = try self.device.dev.acquireNextImageKHR(
//         self.handle,
//         std.math.maxInt(u64),
//         semaphore.handle,
//         fence.handle,
//     );
//
//     switch (result.result) {
//         .success => {
//             return result.image_index;
//         },
//         .suboptimal_khr => {
//             return result.image_index;
//         },
//         else => unreachable,
//     }
// }
