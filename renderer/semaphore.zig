const std = @import("std");
const vk = @import("vulkan");
const Device = @import("device.zig").Device;

pub const Semaphore = struct {
    handle: vk.Semaphore = vk.Semaphore.null_handle,

    const Self = @This();

    pub fn init(dev: Device) !Self {
        const handle = try dev.vkd.createSemaphore(dev.logical, &.{ .flags = .{} }, null);

        return Self{
            .handle = handle,
        };
    }

    pub fn deinit(self: Self, dev: Device) void {
        dev.vkd.destroySemaphore(dev.logical, self.handle, null);
    }
};
