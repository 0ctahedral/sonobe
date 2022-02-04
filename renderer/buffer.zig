const std = @import("std");
const vk = @import("vulkan");
const Device = @import("device.zig").Device;
const Queue = @import("device.zig").Queue;
//const Fence = @import("fence.zig").Fence;
const CommandBuffer = @import("commandbuffer.zig").CommandBuffer;

// this will go somewhere else too
pub const Buffer = struct {
    handle: vk.Buffer,
    usage: vk.BufferUsageFlags,
    mem: vk.DeviceMemory,

    locked: bool = false,

    index: u32,
    mem_flags: vk.MemoryPropertyFlags,

    size: usize,

    const Self = @This();

    pub fn init(
        dev: Device,
        size: usize,
        usage: vk.BufferUsageFlags,
        mem_flags: vk.MemoryPropertyFlags,
        bind_on_create: bool,
    ) !Self {
        var self: Self = undefined;
        self.size = size;
        self.usage = usage;
        self.mem_flags = mem_flags;

        // create handle
        self.handle = try dev.vkd.createBuffer(dev.logical, &.{
            .flags = .{},
            .size = size,
            .usage = usage,
            // only used in one queue
            .sharing_mode = .exclusive,
            .queue_family_index_count = 0,
            .p_queue_family_indices = undefined,
        }, null);

        // get memory
        const reqs = dev.vkd.getBufferMemoryRequirements(dev.logical, self.handle);

        // get memory index TODO: move to device?
        if (dev.findMemoryIndex(reqs.memory_type_bits, mem_flags)) |idx| {
            self.index = idx;
        } else {
            return error.CantFindMemType;
        }

        self.mem = try dev.vkd.allocateMemory(dev.logical, &.{
            .allocation_size = reqs.size,
            .memory_type_index = self.index,
        }, null);

        if (bind_on_create) {
            try self.bind(dev);
        }

        return self;
    }

    pub fn deinit(
        self: Self,
        dev: Device,
    ) void {
        dev.vkd.freeMemory(dev.logical, self.mem, null);
        dev.vkd.destroyBuffer(dev.logical, self.handle, null);
    }

    pub fn lock(
        self: Self,
        dev: Device,
        offset: usize,
        size: usize,
        flags: u32,
    ) !*anyopaque {
        const data = try dev.vkd.mapMemory(dev.logical, self.mem, offset, size, flags);
        self.locked = true;
        return data;
    }

    pub fn unlock(
        self: Self,
        dev: Device,
    ) !void {
        dev.vkd.unmapMemory(dev.logical, self.mem);
        self.locked = false;
    }

    pub fn load(
        self: Self,
        dev: Device,
        comptime T: type,
        data: []T,
        offset: usize,
    ) !void {
        //var ptr = @ptrCast([*]u8, try dev.vkd.mapMemory(dev.logical, self.mem, offset, size, .{}));
        //

        const dest = try dev.vkd.mapMemory(dev.logical, self.mem, @sizeOf(T) * offset, @sizeOf(T) * data.len, .{});
        const ptr = @ptrCast([*]T, @alignCast(@alignOf(T), dest));

        for (data) |item, i| {
            ptr[i] = item;
        }

        dev.vkd.unmapMemory(dev.logical, self.mem);
    }

    pub fn bind(self: Self, dev: Device) !void {
        try dev.vkd.bindBufferMemory(dev.logical, self.handle, self.mem, 0);
    }

    pub fn resize(
        self: *Self,
        dev: Device,
        pool: vk.CommandPool,
        queue: Queue,
        new_size: usize,
    ) !void {
        // make a new buffer
        var new_buf = try init(
            dev,
            new_size,
            self.usage,
            self.mem_flags,
            false,
        );

        try new_buf.bind(dev);

        try copyTo(self, new_buf, dev, pool, .null_handle, queue.handle, 0, 0, self.size);

        try dev.vkd.deviceWaitIdle(dev.logical);

        self = new_buf;
    }

    pub fn copyTo(
        src: Self,
        dest: Self,
        dev: Device,
        pool: vk.CommandPool,
        //fence: Fence,
        queue: Queue,
        src_offset: usize,
        dest_offset: usize,
        size: usize,
    ) !void {
        try dev.vkd.queueWaitIdle(queue.handle);
        var tmp_buf = try CommandBuffer.beginSingleUse(dev, pool);

        const bc = [_]vk.BufferCopy{.{
            .src_offset = src_offset,
            .dst_offset = dest_offset,
            .size = size,
        }};

        dev.vkd.cmdCopyBuffer(tmp_buf.handle, src.handle, dest.handle, 1, &bc);

        try tmp_buf.endSingleUse(dev, pool, queue.handle);
    }
};
