const std = @import("std");
const vk = @import("vulkan");
const dispatch_types = @import("dispatch_types.zig");
const InstanceDispatch = dispatch_types.InstanceDispatch;
const Device = @import("device.zig").Device;
const Queue = @import("device.zig").Queue;
const Image = @import("image.zig").Image;
const Fence = @import("fence.zig").Fence;
const Semaphore = @import("semaphore.zig").Semaphore;
const RenderPass = @import("renderpass.zig").RenderPass;

pub const Swapchain = struct {
    surface_format: vk.SurfaceFormatKHR = undefined,
    // defaults to fifo which all devices support
    present_mode: vk.PresentModeKHR = .fifo_khr,
    //extent: vk.Extent2D = undefined,

    handle: vk.SwapchainKHR = .null_handle,

    images: []Image = undefined,
    framebuffers: []vk.Framebuffer = undefined,

    depth: Image = undefined,

    const Self = @This();

    /// initialize/create a swapchian object
    pub fn init(vki: InstanceDispatch, dev: Device, surface: vk.SurfaceKHR, w: u32, h: u32, allocator: std.mem.Allocator) !Self {
        return try create(vki, dev, surface, w, h, allocator);
    }

    /// shutdown a swapchian object
    pub fn deinit(self: *Self, dev: Device, allocator: std.mem.Allocator) void {
        self.destroy(dev);
        allocator.free(self.framebuffers);
        allocator.free(self.images);
    }

    /// create our swapchain
    fn create(vki: InstanceDispatch, dev: Device, surface: vk.SurfaceKHR, w: u32, h: u32, allocator: std.mem.Allocator) !Self {
        var self: Self = .{};

        var extent = vk.Extent2D{ .width = w, .height = h };

        // find the format
        const preferred_format = vk.SurfaceFormatKHR{
            .format = .b8g8r8a8_srgb,
            .color_space = .srgb_nonlinear_khr,
        };
        var surface_formats: [32]vk.SurfaceFormatKHR = undefined;
        var count: u32 = undefined;
        _ = try vki.getPhysicalDeviceSurfaceFormatsKHR(dev.physical, surface, &count, surface_formats[0..]);

        self.surface_format = surface_formats[0];

        for (surface_formats[0..count]) |sfmt| {
            if (std.meta.eql(sfmt, preferred_format)) {
                self.surface_format = sfmt;
                break;
            }
        }

        // find present mode
        var present_modes: [32]vk.PresentModeKHR = undefined;
        _ = try vki.getPhysicalDeviceSurfacePresentModesKHR(dev.physical, surface, &count, present_modes[0..]);

        for (present_modes[0..count]) |mode| {
            // if we can get mailbox that's ideal
            if (mode == .mailbox_khr) {
                self.present_mode = mode;
                break;
            }
        }

        std.log.info("chosen present mode: {}", .{self.present_mode});

        // get the actual extent of the window
        const caps = try vki.getPhysicalDeviceSurfaceCapabilitiesKHR(dev.physical, surface);

        if (caps.current_extent.width != 0xFFFF_FFFF) {
            extent = caps.current_extent;
        }
        extent.width = std.math.clamp(extent.width, caps.min_image_extent.width, caps.max_image_extent.width);
        extent.height = std.math.clamp(extent.height, caps.min_image_extent.height, caps.max_image_extent.height);

        if (extent.width == 0 or extent.height == 0) {
            return error.InvalidSurfaceDimensions;
        }

        //self.extent = actual_extent;

        //std.log.info("given extent: {} actual extent: {}", .{ extent, self.extent });

        // get the image count
        var image_count = caps.min_image_count + 1;
        if (caps.max_image_count > 0) {
            image_count = std.math.min(image_count, caps.max_image_count);
        }
        image_count = std.math.min(image_count, 3);

        const qfi = [_]u32{ dev.graphics.?.idx, dev.present.?.idx };
        const sharing_mode: vk.SharingMode = if (dev.graphics.?.idx == dev.present.?.idx) .exclusive else .concurrent;

        // create the handle
        self.handle = try dev.vkd.createSwapchainKHR(dev.logical, &.{
            .flags = .{},
            .surface = surface,
            .min_image_count = image_count,
            .image_format = self.surface_format.format,
            .image_color_space = self.surface_format.color_space,
            .image_extent = extent,
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
            .old_swapchain = self.handle,
        }, null);

        // make the images and views
        var imgs: [8]vk.Image = undefined;
        _ = try dev.vkd.getSwapchainImagesKHR(dev.logical, self.handle, &count, null);
        std.log.info("image count: {}", .{count});
        _ = try dev.vkd.getSwapchainImagesKHR(dev.logical, self.handle, &count, imgs[0..]);
        self.images = try allocator.alloc(Image, count);

        for (imgs[0..count]) |img, i| {
            self.images[i] = Image{
                .handle = img,
                .format = self.surface_format.format,
            };

            try self.images[i].createView(dev, self.surface_format.format, .{ .color_bit = true });
        }

        // allocate the framebuffers
        self.framebuffers = try allocator.alloc(vk.Framebuffer, count);

        // create the depth image
        self.depth = try Image.init(dev, .@"2d", extent, dev.depth_format, .optimal, .{ .depth_stencil_attachment_bit = true }, .{ .device_local_bit = true }, .{ .depth_bit = true });

        return self;
    }

    /// destroy our swapchain
    fn destroy(self: *Self, dev: Device) void {
        dev.vkd.deviceWaitIdle(dev.logical) catch {
            unreachable;
        };

        for (self.framebuffers) |fb| {
            dev.vkd.destroyFramebuffer(dev.logical, fb, null);
        }
        for (self.images) |*img| {
            img.deinit(dev);
        }
        self.depth.deinit(dev);
        dev.vkd.destroySwapchainKHR(dev.logical, self.handle, null);
    }

    pub fn recreate(self: *Self, vki: InstanceDispatch, dev: Device, surface: vk.SurfaceKHR, w: u32, h: u32, allocator: std.mem.Allocator) !void {
        self.destroy(dev);
        self.* = try create(vki, dev, surface, w, h, allocator);
    }

    /// present an image to the swapchain
    pub fn present(
        self: Self,
        dev: Device,
        //graphics_queue: Queue,
        present_queue: Queue,
        render_complete: Semaphore,
        idx: u32,
    ) !void {
        const result = try dev.vkd.queuePresentKHR(present_queue.handle, &.{ .wait_semaphore_count = 1, .p_wait_semaphores = render_complete.ptr(), .swapchain_count = 1, .p_swapchains = @ptrCast([*]const vk.SwapchainKHR, &self.handle), .p_image_indices = @ptrCast([*]const u32, &idx), .p_results = null });

        switch (result) {
            .success => {},
            .suboptimal_khr => {
                return error.SuboptimalKHR;
            },
            else => unreachable,
        }
    }

    pub fn acquireNext(
        self: Self,
        dev: Device,
        semaphore: Semaphore,
        fence: Fence,
    ) !u32 {
        const result = try dev.vkd.acquireNextImageKHR(
            dev.logical,
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

    // also should probably be in the swapchain??
    pub fn recreateFramebuffers(self: *Self, dev: Device, renderpass: RenderPass, w: u32, h: u32) !void {
        std.log.info("fbw: {} fbh: {}", .{ w, h });
        for (self.images) |img, i| {
            const attachments = [_]vk.ImageView{ img.view, self.depth.view };

            self.framebuffers[i] = try dev.vkd.createFramebuffer(dev.logical, &.{
                .flags = .{},
                .render_pass = renderpass.handle,
                .attachment_count = attachments.len,
                .p_attachments = @ptrCast([*]const vk.ImageView, &attachments),
                .width = w,
                .height = h,
                .layers = 1,
            }, null);
        }
    }
};
