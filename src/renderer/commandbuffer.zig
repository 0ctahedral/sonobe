const dispatch_types = @import("dispatch_types.zig");
const BaseDispatch = dispatch_types.BaseDispatch;
const InstanceDispatch = dispatch_types.InstanceDispatch;
const std = @import("std");
const vk = @import("vulkan");
const Device = @import("device.zig").Device;
const RenderPass = @import("renderpass.zig").RenderPass;
const RenderPassInfo = @import("renderpass.zig").RenderPassInfo;
const Renderer = @import("../renderer.zig");
const Buffer = @import("buffer.zig").Buffer;

pub const CommandBuffer = struct {

    //TODO: check state
    const State = enum { ready, recording, in_render_pass, recording_ended, submitted, not_allocated };

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
        try dev.vkd.allocateCommandBuffers(dev.logical, &.{
            .command_pool = pool,
            .level = if (is_primary) vk.CommandBufferLevel.primary else vk.CommandBufferLevel.secondary,
            .command_buffer_count = 1,
        }, @ptrCast([*]vk.CommandBuffer, &self.handle));
        self.state = .ready;
        return self;
    }

    /// free command buffer back to the pool
    pub fn deinit(self: *Self, dev: Device, pool: vk.CommandPool) void {
        dev.vkd.freeCommandBuffers(dev.logical, pool, 1, @ptrCast([*]vk.CommandBuffer, &self.handle));
        self.handle = vk.CommandBuffer.null_handle;
        self.state = .not_allocated;
    }

    const beginmask = packed struct {
        // each recording will be done between uses
        single_use: bool = false,
        // secondary buffer inside pass
        rp_continue: bool = false,
        // can be resubmitted while pending
        simultaneous_use: bool = false,
    };

    pub fn begin(
        self: *Self,
        mask: beginmask,
    ) !void {
        var flags = vk.CommandBufferUsageFlags{};
        if (mask.single_use) {
            flags.one_time_submit_bit = true;
        }
        if (mask.rp_continue) {
            flags.render_pass_continue_bit = true;
        }
        if (mask.simultaneous_use) {
            flags.simultaneous_use_bit = true;
        }
        try Renderer.device.vkd.beginCommandBuffer(self.handle, &.{
            .flags = flags,
            .p_inheritance_info = null,
        });
        self.state = .recording;
    }

    pub fn end(self: *Self) !void {
        try Renderer.device.vkd.endCommandBuffer(self.handle);
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
        var self = try init(dev, pool, true);
        try self.begin(.{ .single_use = true });
        return self;
    }

    pub fn endSingleUse(
        self: *Self,
        dev: Device,
        pool: vk.CommandPool,
        queue: vk.Queue,
    ) !void {
        try self.end();
        const si = vk.SubmitInfo{
            .wait_semaphore_count = 0,
            .p_wait_semaphores = undefined,
            .p_wait_dst_stage_mask = undefined,
            .command_buffer_count = 1,
            .p_command_buffers = @ptrCast([*]const vk.CommandBuffer, &self.handle),
            .signal_semaphore_count = 0,
            .p_signal_semaphores = undefined,
        };
        try dev.vkd.queueSubmit(queue, 1, @ptrCast([*]const vk.SubmitInfo, &si), .null_handle);

        // not using a fence so we wait
        try dev.vkd.queueWaitIdle(queue);
        self.deinit(dev, pool);
    }

    // --------------------- helpers --------------------------------
    /// reduces boilerplate for beginning rp
    pub fn beginRenderPass(
        self: *Self,
        rpi: RenderPassInfo,
    ) !void {
        // set the viewport
        const viewport = vk.Viewport{ .x = 0, .y = @intToFloat(f32, Renderer.fb_height), .width = @intToFloat(f32, Renderer.fb_width), .height = -@intToFloat(f32, Renderer.fb_height), .min_depth = 0, .max_depth = 1 };
        Renderer.device.vkd.cmdSetViewport(self.handle, 0, 1, @ptrCast([*]const vk.Viewport, &viewport));

        // set the scissor (region we are clipping)
        const scissor = vk.Rect2D{
            .offset = .{ .x = 0, .y = 0 },
            .extent = .{
                .width = Renderer.fb_width,
                .height = Renderer.fb_height,
            },
        };

        Renderer.device.vkd.cmdSetScissor(self.handle, 0, 1, @ptrCast([*]const vk.Rect2D, &scissor));

        var rp: RenderPass = undefined;
        var fb: vk.Framebuffer = undefined;

        // TODO: make these functions of somewhere
        if (Renderer.renderpass_cache.get(rpi)) |cached| {
            rp = cached;
        } else {
            var new = try Renderer.RenderPass.init(Renderer.swapchain, Renderer.device, rpi);
            try Renderer.renderpass_cache.putNoClobber(rpi, new);
            rp = new;
        }

        if (Renderer.fb_cache.get(rpi)) |cached| {
            fb = cached;
        } else {
            // TODO: dont hard code
            const attachments = [_]vk.ImageView{ rpi.color_attachments[0].view, rpi.depth_attachment.?.view };

            const framebuffer: vk.Framebuffer = try Renderer.device.vkd.createFramebuffer(Renderer.device.logical, &.{
                .flags = .{},
                .render_pass = rp.handle,
                .attachment_count = attachments.len,
                .p_attachments = @ptrCast([*]const vk.ImageView, &attachments),
                .width = Renderer.fb_width,
                .height = Renderer.fb_height,
                .layers = 1,
            }, null);
            try Renderer.fb_cache.putNoClobber(rpi, framebuffer);
            fb = framebuffer;
        }

        var num_clear: u32 = 0;

        var clear_values: [RenderPassInfo.MAX_ATTATCHMENTS + 1]vk.ClearValue = undefined;
        for (rpi.clear_colors[0..rpi.n_color_attachments])  |clear, i| {
            clear_values[i] = vk.ClearValue{ .color = clear };
            num_clear += 1;
        }

        if (rpi.depth_attachment) |_| {
            clear_values[rpi.n_color_attachments] = vk.ClearValue{ .depth_stencil = rpi.clear_depth};
            num_clear += 1;
        }

        const area = vk.Rect2D{
            .offset = .{ .x = 0, .y = 0 }, .extent = .{
                .width = Renderer.fb_width,
                .height = Renderer.fb_height,
            } 
        };

        
        Renderer.device.vkd.cmdBeginRenderPass(self.handle, &.{
            .render_pass = rp.handle,
            .framebuffer = fb,
            .render_area = area,
            .clear_value_count = num_clear,
            .p_clear_values = clear_values[0..num_clear].ptr,
        }, .@"inline");
    }

    pub fn endRenderPass(
        self: *Self,
    ) void {
        Renderer.device.vkd.cmdEndRenderPass(self.handle);
    }

    /// TODO: move this
    pub fn pushConstant(
        self: *Self,
        comptime T: type,
        value: anytype
    ) void {
        Renderer.device.vkd.cmdPushConstants(self.handle,
            Renderer.pipeline.layout,
            .{ .vertex_bit = true }, 0, @intCast(u32, @sizeOf(T)), &value);
    }

    pub fn drawIndexed(
        self: *Self,
        num_indices: u32,
        vbuf: Buffer,
        ibuf: Buffer,
        first: u32,
        offset: u32,
    ) void {
        // setup descriptor sets and stuff

        // TODO: separate this to pipeline layer
        Renderer.device.vkd.cmdBindPipeline(self.handle, .graphics, Renderer.pipeline.handle);

        Renderer.device.vkd.cmdBindDescriptorSets(
            self.handle,
            .graphics,
            Renderer.pipeline.layout,
            0,
            1,
            @ptrCast([*]const vk.DescriptorSet, &Renderer.getCurrentFrame().global_descriptor_set),
            0,
            undefined,
        );

        const bind_offset = [_]vk.DeviceSize{0};
        Renderer.device.vkd.cmdBindVertexBuffers(self.handle, 0, 1, @ptrCast([*]const vk.Buffer, &vbuf.handle), &bind_offset);
        Renderer.device.vkd.cmdBindIndexBuffer(self.handle, ibuf.handle, 0, .uint32);

        // actually draw
        Renderer.device.vkd.cmdDrawIndexed(self.handle, num_indices, 1, first, @intCast(i32, offset), 0);
    }


};
