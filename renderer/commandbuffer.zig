const dispatch_types = @import("dispatch_types.zig");
const BaseDispatch = dispatch_types.BaseDispatch;
const InstanceDispatch = dispatch_types.InstanceDispatch;
const std = @import("std");
const vk = @import("vulkan");
const Device = @import("device.zig").Device;

pub const CommandBuffer = struct {

    //TODO: check state
    const State = enum {
        ready,
        recording,
        in_render_pass,
        recording_ended,
        submitted,
        not_allocated
    };

    handle: vk.CommandBuffer = vk.CommandBuffer.null_handle,

    state: State = .not_allocated,

    const Self = @This();

    /// allocate command buffer from the pool
    pub fn init(
        dev: Device,
        pool: vk.CommandPool,
        is_primary: bool,
    ) !Self {
        var self = Self{};
        try dev.vkd.allocateCommandBuffers(
            dev.logical,
            &.{
                .command_pool = pool,
                .level = if (is_primary) vk.CommandBufferLevel.primary else vk.CommandBufferLevel.secondary,
                .command_buffer_count = 1,
            },
            @ptrCast([*]vk.CommandBuffer, &self.handle)
        );
        self.state = .ready;
        return self;
    }

    /// free command buffer back to the pool
    pub fn deinit(
        self: *Self,
        dev: Device,
        pool: vk.CommandPool
    ) void {
        dev.vkd.freeCommandBuffers(
            dev.logical,
            pool,
            1,
            @ptrCast([*]vk.CommandBuffer, &self.handle)
        );
        self.handle = vk.CommandBuffer.null_handle;
        self.state = .not_allocated;
    }

    const beginmask = packed struct {
            // each recording will be done between uses
            single_use: bool = false,
            // secondary buffer inside pass
            renderpass_continue: bool = false,
            // can be resubmitted while pending
            simultaneous_use: bool = false,
        };

    pub fn begin(
        self: *Self,
        dev: Device,
        mask: beginmask,
    ) !void {
        var flags = vk.CommandBufferUsageFlags{};
        if (mask.single_use) {
            flags.one_time_submit_bit = true;
        }
        if (mask.renderpass_continue) {
            flags.render_pass_continue_bit = true;
        }
        if (mask.simultaneous_use) {
            flags.simultaneous_use_bit = true;
        }
        try dev.vkd.beginCommandBuffer(self.handle, &.{
            .flags = flags,
            .p_inheritance_info = null,
        });
        self.state = .recording;
    }

    pub fn end(self: *Self, dev: Device) !void {
        try dev.vkd.endCommandBuffer(self.handle);
        self.state = .recording_ended;
    }

    /// update submitted buffer
    pub fn updateSubmitted(self: *Self) void {
        self.state = .submitted;
    }

    /// reset buffer
    pub fn reset(self: *Self) void {
        self.state = .ready;
    }
    

    /// for single use
    pub fn beginSingleUse(
        dev: Device,
        pool: vk.CommandPool,
    ) !Self {
        const self = try init(dev, pool, true);
        self.begin(dev, .{ .single_use = true });
        return self;
    }

    pub fn endSingleUse(
        self: Self,
        dev: Device,
        pool: vk.CommandPool,
        queue: vk.Queue,
    ) !void {
        self.end(dev);
        try dev.vkd.queueSubmit(queue, 1, &.{
            .wait_semaphore_count = 0,
            .p_wait_semaphores = undefined,
            .p_wait_dst_stage_mask = undefined,
            .command_buffer_count = 1,
            .p_command_buffers = @ptrCast([*]const vk.CommandBuffer, &self.handle),
            .signal_semaphore_count = 0,
            .p_signal_semaphores = undefined,
        });

        // not using a fence so we wait
        try dev.vkd.queueWaitIdle(queue);
        self.deinit(dev, pool);
    }
};
