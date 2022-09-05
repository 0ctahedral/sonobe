const std = @import("std");
const vk = @import("vulkan");
const Device = @import("device.zig").Device;

/// Synchronizes dependencies on gpu data
pub const Semaphore = struct {
    handle: vk.Semaphore = vk.Semaphore.null_handle,

    const Self = @This();

    /// create a new Semaphore
    pub fn init(dev: Device) !Self {
        const handle = try dev.vkd.createSemaphore(dev.logical, &.{ .flags = .{} }, null);

        return Self{
            .handle = handle,
        };
    }

    /// destroy Semaphore
    pub fn deinit(self: Self, dev: Device) void {
        dev.vkd.destroySemaphore(dev.logical, self.handle, null);
    }

    /// convinience function for when a multi item pointer is needed
    pub inline fn ptr(self: Self) [*]const vk.Semaphore {
        return @ptrCast([*]const vk.Semaphore, &self.handle);
    }
};
