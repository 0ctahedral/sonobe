const std = @import("std");
const vk = @import("vulkan");

// TODO: get rid of this dependency if possible
const platform = @import("../../platform.zig");

const types = @import("../rendertypes.zig");
const Handle = types.Handle;
const CmdBuf = @import("../cmdbuf.zig");

const dispatch_types = @import("dispatch_types.zig");
const BaseDispatch = dispatch_types.BaseDispatch;
const InstanceDispatch = dispatch_types.InstanceDispatch;
const Allocator = std.mem.Allocator;

const Device = @import("device.zig").Device;
const Queue = @import("device.zig").Queue;
const Swapchain = @import("swapchain.zig").Swapchain;
const RenderPass = @import("renderpass.zig").RenderPass;
const CommandBuffer = @import("commandbuffer.zig").CommandBuffer;
const Fence = @import("fence.zig").Fence;
const Semaphore = @import("semaphore.zig").Semaphore;
const Mesh = @import("mesh.zig").Mesh;
const Texture = @import("texture.zig").Texture;
const RenderTarget = @import("render_target.zig").RenderTarget;
pub const resources = @import("resources.zig");
const math = @import("../../math.zig");
const Mat4 = math.Mat4;
const Vec4 = math.Vec4;
const Vec3 = math.Vec3;
const Vec2 = math.Vec2;

// TODO: set this in a config
const required_layers = [_][*:0]const u8{"VK_LAYER_KHRONOS_validation"};

var vkb: BaseDispatch = undefined;
var vki: InstanceDispatch = undefined;
var instance: vk.Instance = undefined;
var surface: vk.SurfaceKHR = undefined;
var messenger: vk.DebugUtilsMessengerEXT = undefined;
var device: Device = undefined;
var swapchain: Swapchain = undefined;

/// monotonically increasing frame number
var frame_number: usize = 0;

/// index of the image in the swapchain we are currently
/// rendering to
/// TODO: do we still need this?
var image_index: usize = 0;

/// Allocator used by the renderer
var allocator: Allocator = undefined;

// TODO: these will eventually not exist

var default_renderpass: Handle = .{};

/// current dimesnsions of the framebuffer
var fb_width: u32 = 0;
var fb_height: u32 = 0;

/// swapchain render targets
var swapchain_render_targets: []RenderTarget = undefined;

pub const MAX_FRAMES = 2;
/// The currently rendering frames
var frames: [MAX_FRAMES]FrameData = undefined;

// -------------------------------

/// Are we currently recreating the swapchain
/// I don't think this is really used yet but might
/// be useful when we multi thread
var recreating_swapchain = false;

// TODO: might not need
/// generation of this resize
var size_gen: usize = 0;
var last_size_gen: usize = 0;

// functions that are part of the api

// initialize the renderer
// TODO: should this take in a surface instead of a window?
pub fn init(provided_allocator: Allocator, app_name: [*:0]const u8, window: platform.Window) !void {
    allocator = provided_allocator;
    // open vulkan dynlib
    // TODO: make local or whatever
    var vk_proc = platform.getInstanceProcAddress();

    // get proc address from glfw window
    // load the base dispatch functions
    vkb = try BaseDispatch.load(vk_proc);

    const size = try platform.getWindowSize(window);

    fb_width = @as(usize, size.w);
    fb_height = @as(usize, size.h);

    const app_info = vk.ApplicationInfo{
        .p_application_name = app_name,
        .application_version = vk.makeApiVersion(0, 0, 0, 0),
        .p_engine_name = app_name,
        .engine_version = vk.makeApiVersion(0, 0, 0, 0),
        .api_version = vk.API_VERSION_1_2,
    };

    // create an instance
    instance = try vkb.createInstance(&.{
        .flags = .{},
        .p_application_info = &app_info,
        .enabled_layer_count = required_layers.len,
        //.enabled_layer_count = 0,
        .pp_enabled_layer_names = &required_layers,
        .enabled_extension_count = @intCast(u32, platform.required_exts.len),
        .pp_enabled_extension_names = @ptrCast([*]const [*:0]const u8, &platform.required_exts),
    }, null);

    // load dispatch functions which require instance
    vki = try InstanceDispatch.load(instance, vk_proc);
    errdefer vki.destroyInstance(instance, null);

    // setup debug msg
    messenger = try vki.createDebugUtilsMessengerEXT(
        instance,
        &.{
            .message_severity = .{
                .warning_bit_ext = true,
                .error_bit_ext = true,
                .info_bit_ext = true,
                //.verbose_bit_ext = true,
            },
            .message_type = .{
                .general_bit_ext = true,
                .validation_bit_ext = true,
                .performance_bit_ext = true,
            },
            .pfn_user_callback = vk_debug,
            .flags = .{},
            .p_user_data = null,
        },
        null,
    );
    errdefer vki.destroyDebugUtilsMessengerEXT(instance, messenger, null);

    // TODO: move this to system
    surface = try platform.createWindowSurface(vki, instance, window);
    errdefer vki.destroySurfaceKHR(instance, surface, null);

    // create a device
    // load dispatch functions which require device
    device = try Device.init(.{
        .graphics = true,
        .present = true,
        .transfer = true,
        .discrete = false,
        .compute = true,
    }, instance, vki, surface, allocator);
    errdefer device.deinit();

    try resources.init(device, allocator);

    swapchain = try Swapchain.init(vki, device, surface, fb_width, fb_height, allocator);
    errdefer swapchain.deinit(device, allocator);

    // subscribe to resize events

    // create a default_renderpass
    default_renderpass = try resources.createRenderPass(
        .{
            .clear_flags = .{
                .color = true,
                .depth = true,
                .stencil = true,
            },
            .clear_color = Vec4.new(0, 0, 0.1, 1),
            .clear_depth = 1.0,
            .clear_stencil = 0,
        },
    );

    // create framebuffers
    std.log.info("fbw: {} fbh: {}", .{ fb_width, fb_width });
    swapchain_render_targets = try allocator.alloc(RenderTarget, swapchain.img_count);
    for (swapchain_render_targets) |*rt| {
        rt.framebuffer = .null_handle;
    }
    try recreateRenderTargets();

    for (frames) |*f, i| {
        f.* = try FrameData.init(device, i);
    }
}

// shutdown the renderer
pub fn deinit() void {

    // wait until rendering is done
    device.vkd.deviceWaitIdle(device.logical) catch {
        unreachable;
    };

    resources.deinit();

    for (frames) |*f| {
        f.deinit(device);
    }

    swapchain.deinit(device, allocator);
    for (swapchain_render_targets) |*rt| {
        rt.deinit(device, allocator);
    }
    allocator.free(swapchain_render_targets);

    device.deinit();

    vki.destroySurfaceKHR(instance, surface, null);

    vki.destroyDebugUtilsMessengerEXT(instance, messenger, null);
    vki.destroyInstance(instance, null);
}

pub fn onResize(w: u32, h: u32) void {
    size_gen += 1;
    std.log.warn("resize triggered: {}x{}, gen: {}", .{ w, h, size_gen });
    fb_width = w;
    fb_height = h;
}

pub fn beginFrame() !bool {
    if (recreating_swapchain) {
        std.log.info("waiting for swapchain", .{});
        try device.vkd.deviceWaitIdle(device.logical);
        return false;
    }

    if (size_gen != last_size_gen) {
        try device.vkd.deviceWaitIdle(device.logical);

        if (!try recreateSwapchain()) {
            return false;
        }

        std.log.info("resized, booting frame", .{});
        return false;
    }

    // wait for current frame
    //std.log.info("waiting for render fence: {}", .{getCurrentFrame().render_fence.handle});
    try getCurrentFrame().render_fence.wait(device, std.math.maxInt(u64));

    image_index = swapchain.acquireNext(device, getCurrentFrame().image_available, Fence{}) catch |err| {
        switch (err) {
            error.OutOfDateKHR => {
                std.log.warn("failed to aquire, booting", .{});
                return false;
            },
            else => |narrow| return narrow,
        }
    };

    try getCurrentFrame().render_fence.reset(device);

    return true;
}

/// subit a command buffer
pub fn submit(cmdbuf: CmdBuf) !void {
    var cb: *CommandBuffer = &getCurrentFrame().cmdbuf;
    cb.reset();
    try cb.begin(device, .{});

    var i: usize = 0;
    while (i < cmdbuf.idx) : (i += 1) {
        switch (cmdbuf.commands[i]) {
            .PushConst => |desc| applyPushConst(cb, desc),
            .DrawIndexed => |desc| applyDrawIndexed(cb, desc),
            .BeginRenderPass => |handle| applyBeginRenderPass(cb, handle),
            .EndRenderPass => |handle| applyEndRenderPass(cb, handle),
            .BindPipeline => |handle| try applyBindPipeline(cb, handle),
        }
    }

    try cb.end(device);
}

fn applyPushConst(cb: *CommandBuffer, desc: types.PushConstDesc) void {
    const pl = resources.getPipeline(desc.pipeline);
    device.vkd.cmdPushConstants(
        cb.handle,
        pl.layout,
        .{ .vertex_bit = true, .fragment_bit = true },
        0,
        @intCast(u32, desc.size),
        &desc.data,
    );
}

fn applyBindPipeline(cb: *CommandBuffer, handle: types.Handle) !void {
    const pl = resources.getPipeline(handle);
    device.vkd.cmdBindPipeline(cb.handle, .graphics, pl.handle);

    var descriptor_sets: [8]vk.DescriptorSet = undefined;
    const res = resources.resources.get(handle.resource).Pipeline;
    var i: usize = 0;
    while (i < res.n_bind_groups) : (i += 1) {
        const bg = resources.getBindGroup(res.bind_groups[i]);
        descriptor_sets[i] = bg.sets[getCurrentFrame().index];
    }

    device.vkd.cmdBindDescriptorSets(
        cb.handle,
        .graphics,
        pl.layout,
        0,
        @intCast(u32, res.n_bind_groups),
        &descriptor_sets,
        0,
        undefined,
    );
}

fn applyBeginRenderPass(cb: *CommandBuffer, handle: types.Handle) void {
    // set the viewport
    const viewport = vk.Viewport{
        .x = 0,
        .y = 0,
        .width = @intToFloat(f32, fb_width),
        .height = @intToFloat(f32, fb_height),
        .min_depth = 0,
        .max_depth = 1,
    };
    device.vkd.cmdSetViewport(cb.handle, 0, 1, @ptrCast([*]const vk.Viewport, &viewport));

    // set the scissor (region we are clipping)
    const scissor = vk.Rect2D{
        .offset = .{ .x = 0, .y = 0 },
        .extent = .{
            .width = fb_width,
            .height = fb_height,
        },
    };

    device.vkd.cmdSetScissor(cb.handle, 0, 1, @ptrCast([*]const vk.Rect2D, &scissor));

    resources.getRenderPass(handle).begin(device, cb, swapchain_render_targets[image_index].framebuffer, .{ .offset = .{ .x = 0, .y = 0 }, .extent = .{
        .width = fb_width,
        .height = fb_height,
    } });
}

fn applyEndRenderPass(cb: *CommandBuffer, handle: types.Handle) void {
    _ = handle;
    resources.getRenderPass(handle).end(device, cb);
}

fn applyDrawIndexed(cb: *CommandBuffer, desc: types.DrawIndexedDesc) void {
    // const n_attr = @intCast(u32, @minimum(16, desc.vertex_offsets.len));
    var vertex_offsets = [_]vk.DeviceSize{0} ** 16;
    var buffers = [_]vk.Buffer{.null_handle} ** 16;
    if (desc.n_vertex_offsets > 0) {
        {
            var i: usize = 0;
            while (i < desc.n_vertex_offsets) : (i += 1) {
                vertex_offsets[i] = desc.vertex_offsets[i];
                buffers[i] = resources.getBuffer(desc.vertex_handle).handle;
            }
        }
        device.vkd.cmdBindVertexBuffers(
            cb.handle,
            0,
            desc.n_vertex_offsets,
            @ptrCast([*]const vk.Buffer, buffers[0..]),
            &vertex_offsets,
        );
    }
    device.vkd.cmdBindIndexBuffer(
        cb.handle,
        resources.getBuffer(desc.index_handle).handle,
        desc.index_offset,
        .uint32,
    );

    device.vkd.cmdDrawIndexed(cb.handle, desc.count, 1, 0, 0, 0);
}

pub fn endFrame() !void {
    var cb: *CommandBuffer = &getCurrentFrame().cmdbuf;

    // waits for the this stage to write
    const wait_stage = [_]vk.PipelineStageFlags{.{ .color_attachment_output_bit = true }};

    try device.vkd.queueSubmit(device.graphics.?.handle, 1, &[_]vk.SubmitInfo{.{
        .command_buffer_count = 1,
        .p_command_buffers = @ptrCast([*]const vk.CommandBuffer, &cb.handle),

        // signaled when queue is complete
        .signal_semaphore_count = 1,
        .p_signal_semaphores = getCurrentFrame().render_finished.ptr(),

        // wait for this before we start
        .wait_semaphore_count = 1,
        .p_wait_semaphores = getCurrentFrame().image_available.ptr(),

        .p_wait_dst_stage_mask = &wait_stage,
    }}, getCurrentFrame().render_fence.handle);

    cb.updateSubmitted();

    // present that shit
    swapchain.present(device, device.present.?, getCurrentFrame().render_finished, @intCast(u32, image_index)) catch |err| {
        switch (err) {
            error.OutOfDateKHR => {
                std.log.warn("swapchain out of date in end frame", .{});
            },
            else => |narrow| return narrow,
        }
    };

    frame_number += 1;
}

// helpers

fn vk_debug(
    message_severity: vk.DebugUtilsMessageSeverityFlagsEXT.IntType,
    message_types: vk.DebugUtilsMessageTypeFlagsEXT.IntType,
    p_callback_data: ?*const vk.DebugUtilsMessengerCallbackDataEXT,
    p_user_data: ?*anyopaque,
) callconv(vk.vulkan_call_conv) vk.Bool32 {
    _ = message_severity;
    _ = message_types;
    _ = p_callback_data;
    _ = p_user_data;
    std.log.info("{s}", .{p_callback_data.?.*.p_message});
    return vk.FALSE;
}

pub fn recreateRenderTargets() !void {
    std.log.info("fbw: {} fbh: {}", .{ fb_width, fb_height });
    for (swapchain.render_textures) |tex, i| {
        const attachments = [_]Texture{ tex, swapchain.depth_texture };

        swapchain_render_targets[i].reset(device);

        try swapchain_render_targets[i].init(
            device,
            resources.getRenderPass(default_renderpass).handle,
            attachments[0..],
            fb_width,
            fb_height,
            allocator,
        );
    }
}

fn recreateSwapchain() !bool {
    if (recreating_swapchain) {
        std.log.warn("already recreating", .{});
        return false;
    }

    if (fb_width == 0 or fb_height == 0) {
        std.log.info("dimesnsion is zero so, no", .{});
        return false;
    }

    recreating_swapchain = true;
    std.log.info("recreating swapchain", .{});

    try device.vkd.deviceWaitIdle(device.logical);
    std.log.info("device done waiting", .{});

    try swapchain.recreate(vki, device, surface, fb_width, fb_height, allocator);

    last_size_gen = size_gen;

    // destroy the sync objects
    for (frames) |*f| {
        f.render_fence.deinit(device);
        f.cmdbuf.deinit(device, device.command_pool);
    }

    // create the framebuffers
    try recreateRenderTargets();

    // create the command buffers
    for (frames) |*f| {
        f.render_fence = try Fence.init(device, true);
        f.cmdbuf = try CommandBuffer.init(device, device.command_pool, true);
    }

    recreating_swapchain = false;
    std.log.info("done recreating swapchain", .{});

    return true;
}

/// Returns the framedata of the frame we should be on
inline fn getCurrentFrame() *FrameData {
    return &frames[frame_number % frames.len];
}

/// What you need for a single frame
const FrameData = struct {
    // what number frame is this?
    index: usize,
    /// Semaphore signaled when the frame is finished rendering
    render_finished: Semaphore,
    /// semaphore signaled when the frame has been presented by the framebuffer
    image_available: Semaphore,
    /// fence to wait on for this frame to finish rendering
    render_fence: Fence,

    // maybe add a command pool?
    /// Command buffer for this frame
    /// TODO: add a cmdbuf for offscreen rendering and then use this one for rendering to the screen
    cmdbuf: CommandBuffer,

    const Self = @This();

    pub fn init(dev: Device, index: usize) !Self {
        var self: Self = undefined;

        self.index = index;

        self.image_available = try Semaphore.init(dev);
        errdefer self.image_available.deinit(dev);

        self.render_finished = try Semaphore.init(dev);
        errdefer self.render_finished.deinit(dev);

        self.render_fence = try Fence.init(dev, true);
        errdefer self.render_fence.deinit(dev);

        self.cmdbuf = try CommandBuffer.init(dev, dev.command_pool, true);
        errdefer self.cmdbuf.deinit(dev, dev.command_pool);
        return self;
    }

    pub fn deinit(self: *Self, dev: Device) void {
        self.image_available.deinit(dev);
        self.render_finished.deinit(dev);
        self.render_fence.deinit(dev);
        self.cmdbuf.deinit(dev, dev.command_pool);
    }
};
