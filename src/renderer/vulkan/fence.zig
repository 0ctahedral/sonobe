const std = @import("std");
const vk = @import("vulkan");
const Device = @import("device.zig").Device;

/// For synchronization between the gpu and cpu
pub const Fence = struct {
    handle: vk.Fence = vk.Fence.null_handle,

    const Self = @This();

    /// create a new fence
    pub fn init(dev: Device, is_signaled: bool) !Self {
        const handle = try dev.vkd.createFence(dev.logical, &.{ .flags = .{ .signaled_bit = if (is_signaled) true else false } }, null);

        return Self{
            .handle = handle,
        };
    }

    /// destroy this fence
    pub fn deinit(self: Self, dev: Device) void {
        dev.vkd.destroyFence(dev.logical, self.handle, null);
    }

    /// reset this fence to unsignaled state
    pub fn reset(self: Self, dev: Device) !void {
        try dev.vkd.resetFences(dev.logical, 1, self.ptr());
    }

    /// wait for this fence to be signaled or the timeout in
    /// nanoseconds to be reached
    pub fn wait(self: Self, dev: Device, timeout: u64) !void {
        _ = try dev.vkd.waitForFences(dev.logical, 1, self.ptr(), vk.TRUE, timeout);
    }

    /// convinience function for when a multi item pointer is needed
    pub inline fn ptr(self: Self) [*]const vk.Fence {
        return @ptrCast([*]const vk.Fence, &self.handle);
    }
};
