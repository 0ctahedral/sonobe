const std = @import("std");
const vk = @import("vulkan");
const Device = @import("device.zig").Device;

pub const Fence = struct {
    handle: vk.Fence = vk.Fence.null_handle,

    const Self = @This();

    pub fn init(dev: Device, is_signaled: bool) !Self {
        const handle = try dev.vkd.createFence(dev.logical, &.{ .flags = .{ .signaled_bit = if (is_signaled) true else false } }, null);

        return Self{
            .handle = handle,
        };
    }

    pub fn deinit(self: Self, dev: Device) void {
        dev.vkd.destroyFence(dev.logical, self.handle, null);
    }

    pub fn reset(self: Self, dev: Device) !void {
        try dev.vkd.resetFences(dev.logical, 1, @ptrCast([*]const vk.Fence, &self.handle));
    }

    pub fn wait(self: Self, dev: Device) !void {
        _ = try dev.vkd.waitForFences(dev.logical, 1, @ptrCast([*]const vk.Fence, &self.handle), vk.TRUE, std.math.maxInt(u64));
    }
};
