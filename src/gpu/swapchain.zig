const std = @import("std");
const vk = @import("vulkan");
const utils = @import("utils");
const log = utils.log.Logger("swapchain");
const dispatch_types = @import("dispatch_types.zig");
const Instance = @import("gpu.zi").InstanceDispatch;
const Device = @import("device.zig").Device;
const Queue = @import("device.zig").Queue;
const Image = @import("image.zig").Image;
const Texture = @import("texture.zig").Texture;
const Fence = @import("fence.zig").Fence;
const Semaphore = @import("semaphore.zig").Semaphore;

pub const Swapchain = struct {
    surface_format: vk.SurfaceFormatKHR = undefined,
    // defaults to fifo which all devices support
    present_mode: vk.PresentModeKHR = .fifo_khr,
    extent: vk.Extent2D = .{ .width = 0, .height = 0},

    handle: vk.SwapchainKHR = .null_handle,

    img_count: u32 = 0,

    render_textures: []Texture = undefined,

    depth_texture: Texture = undefined,

    const Self = @This();

    /// initialize/create a swapchian object
    pub fn init(
        instance: Instance,
        device: Device,
        surface: vk.SurfaceKHR,
        w: u32,
        h: u32,
        allocator: std.mem.Allocator,
    ) !Self {
        var self: Self = .{};
        try self.create(instance, device, surface, w, h, false, allocator);
        return self;
    }

    /// shutdown a swapchian object
    pub fn deinit(self: *Self, device: Device, allocator: std.mem.Allocator) void {
        self.destroy(device);
        device.dev.destroySwapchainKHR(self.handle, null);
        allocator.free(self.render_textures);
    }

    /// create our swapchain
    fn create(
        self: *Self,
        instance: Instance,
        device: Device,
        surface: vk.SurfaceKHR,
        w: u32,
        h: u32,
        is_recreate: bool,
        allocator: std.mem.Allocator,
    ) !void {
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

        log.info("chosen present mode: {}", .{self.present_mode});

        // get the actual extent of the window
        const caps = try instance.getPhysicalDeviceSurfaceCapabilitiesKHR(device.pdev, surface);

        self.extent.width = std.math.clamp(self.extent.width, caps.min_image_extent.width, caps.max_image_extent.width);
        self.extent.height = std.math.clamp(self.extent.height, caps.min_image_extent.height, caps.max_image_extent.height);

        if (self.extent.width == 0 or self.extent.height == 0) {
            return error.InvalidSurfaceDimensions;
        }

        //self.extent = actual_extent;

        //log.info("given extent: {} actual extent: {}", .{ extent, self.extent });

        // get the image count
        var min_imgs = caps.min_image_count + 1;
        if (caps.max_image_count > 0) {
            min_imgs = std.math.min(min_imgs, caps.max_image_count);
        }
        min_imgs = std.math.min(min_imgs, 3);

        const qfi = [_]u32{ device.graphics.?.idx, device.present.?.idx };
        const sharing_mode: vk.SharingMode = if (device.graphics.?.idx == device.present.?.idx) .exclusive else .concurrent;

        const old_handle = self.handle;

        // create the handle
        self.handle = try device.dev.createSwapchainKHR(device.logical, &.{
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
            log.info("destroying old handle: {}", .{old_handle});
            device.dev.destroySwapchainKHR(old_handle, null);
            // allocator.free(self.render_textures);
        }

        // make the images and views
        self.img_count = 0;
        var imgs: [8]vk.Image = undefined;
        _ = try device.dev.getSwapchainImagesKHR(self.handle, &self.img_count, null);
        log.info("image img_count: {}", .{self.img_count});
        _ = try device.dev.getSwapchainImagesKHR(self.handle, &self.img_count, imgs[0..]);

        if (is_recreate) {
            for (self.render_textures) |*tex| {
                tex.deinit(device);
            }
            self.depth_texture.deinit(device);
        } else {
            self.render_textures = try allocator.alloc(Texture, self.img_count);
        }

        // update the textures
        for (imgs[0..self.img_count], 0..) |img, i| {
            self.render_textures[i].image = Image{
                .format = self.surface_format.format,
                .handle = img,
                .width = self.extent.width,
                .height = self.extent.height,
            };
            try self.render_textures[i].image.createView(
                device,
                self.surface_format.format,
                .{ .color_bit = true },
                .@"2d",
            );
        }

        self.depth_texture.image = try Image.init(
            device,
            self.extent.width,
            self.extent.height,
            1,
            device.depth_format,
            .optimal,
            .{ .depth_stencil_attachment_bit = true },
            .{ .device_local_bit = true },
            .{ .depth_bit = true },
            .@"2d",
        );

        // create the depth image
    }

    /// destroy our swapchain
    fn destroy(self: *Self, device: Device) void {
        device.dev.deviceWaitIdle() catch {
            unreachable;
        };

        for (self.render_textures) |*tex| {
            tex.deinit(device);
        }
        self.depth_texture.deinit(device);
    }

    pub fn recreate(self: *Self, instance: Instance, device: Device, surface: vk.SurfaceKHR, w: u32, h: u32, allocator: std.mem.Allocator) !void {
        try self.create(instance, device, surface, w, h, true, allocator);
    }

    /// present an image to the swapchain
    pub fn present(
        self: Self,
        device: Device,
        //graphics_queue: Queue,
        present_queue: Queue,
        render_complete: Semaphore,
        idx: u32,
    ) !void {
        const result = try device.dev.queuePresentKHR(present_queue.handle, &.{
            .wait_semaphore_count = 1,
            .p_wait_semaphores = render_complete.ptr(),
            .swapchain_count = 1,
            .p_swapchains = @ptrCast(&self.handle),
            .p_image_indices = @ptrCast(&idx),
            .p_results = null,
        });

        switch (result) {
            .suboptimal_khr, .success => {},
            else => unreachable,
        }
    }

    pub fn acquireNext(
        self: Self,
        device: Device,
        semaphore: Semaphore,
        fence: Fence,
    ) !u32 {
        const result = try device.dev.acquireNextImageKHR(
            self.handle,
            std.math.maxInt(u64),
            semaphore.handle,
            fence.handle,
        );

        switch (result.result) {
            .success => {
                return result.image_index;
            },
            .suboptimal_khr => {
                return result.image_index;
            },
            else => unreachable,
        }
    }
};
