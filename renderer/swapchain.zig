const std = @import("std");
const vk = @import("vulkan");
const dispatch_types = @import("dispatch_types.zig");
const InstanceDispatch = dispatch_types.InstanceDispatch;
const Device = @import("device.zig").Device;

pub const Swapchain = struct {

    surface_format: vk.SurfaceFormatKHR = undefined,
    // defaults to fifo which all devices support
    present_mode: vk.PresentModeKHR = .fifo_khr,

    const Self = @This();

    /// initialize/create a swapchian object
    pub fn init(
        vki: InstanceDispatch,
        dev: Device,
        surface: vk.SurfaceKHR,
    ) !Self {

        var self: Self = .{};

        // find the format
        const preferred_format = vk.SurfaceFormatKHR{
            .format = .b8g8r8a8_srgb,
            .color_space = .srgb_nonlinear_khr,
        };
        var surface_formats: [32]vk.SurfaceFormatKHR = undefined;
        var count: u32 = undefined;
        _ = try vki.getPhysicalDeviceSurfaceFormatsKHR(dev.physical, surface, &count, surface_formats[0..]);

        self.surface_format = surface_formats[0];
        
        var i: usize = 0;
        while (i < count) : (i += 1) {
            const sfmt = surface_formats[i];
            if (std.meta.eql(sfmt, preferred_format)) {
                self.surface_format = sfmt;
                break;
            }
        }

        std.log.info("chosen surface format: {}", .{self.surface_format});

        // find present mode
        var present_modes: [32]vk.PresentModeKHR = undefined;
        _ = try vki.getPhysicalDeviceSurfacePresentModesKHR(dev.physical, surface, &count, present_modes[0..]);

        i = 0;
        while (i < count) : (i += 1) {
            const mode = present_modes[i];
            // if we can get mailbox that's ideal
            if (mode == .mailbox_khr) {
                self.present_mode = mode;
                break;
            }
        }

        std.log.info("chosen present mode: {}", .{self.present_mode});

        return self;
    }

    /// shutdown a swapchian object
    pub fn deinit() void {

    }

    /// destroy our swapchain
    fn destroy(self: *Self) void {
        _ = self;
    }

    /// create our swapchain
    fn create(
    ) !Self {
        return error.NotImplemented;
    }

    /// present an image to the swapchain
    pub fn present() void {

    }


};
