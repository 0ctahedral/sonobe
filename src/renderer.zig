const std = @import("std");
const vk = @import("vulkan");

const Platform = @import("platform.zig");
const Events = @import("events.zig");

const dispatch_types = @import("renderer/dispatch_types.zig");
const BaseDispatch = dispatch_types.BaseDispatch;
const InstanceDispatch = dispatch_types.InstanceDispatch;
const Allocator = std.mem.Allocator;

const Device = @import("renderer/device.zig").Device;
const Queue = @import("renderer/device.zig").Queue;
const Swapchain = @import("renderer/swapchain.zig").Swapchain;
const RenderPass = @import("renderer/renderpass.zig").RenderPass;
const CommandBuffer = @import("renderer/commandbuffer.zig").CommandBuffer;
const Fence = @import("renderer/fence.zig").Fence;
const Semaphore = @import("renderer/semaphore.zig").Semaphore;
const Shader = @import("renderer/shader.zig").Shader;
const Pipeline = @import("renderer/pipeline.zig").Pipeline;
const Vertex = @import("renderer/mesh.zig").Vertex;
const mmath = @import("math.zig");
const Mat4 = mmath.Mat4;
const Vec3 = mmath.Vec3;
const Buffer = @import("renderer/buffer.zig").Buffer;

// TODO: get these from the system

// TODO: set this in a config
const required_layers = [_][*:0]const u8{"VK_LAYER_KHRONOS_validation"};

var quad_verts = [_]Vertex{
    .{ .pos = Vec3.new(-0.5, -0.5, 0) },
    .{ .pos = Vec3.new(0.5, 0.5, 0) },
    .{ .pos = Vec3.new(-0.5, 0.5, 0) },
    .{ .pos = Vec3.new(0.5, -0.5, 0) },
};

var oct_verts = [_]Vertex{
    .{ .pos = .{ .x = -1.1920928955078125e-07, .y = -1.1920928955078125e-07, .z = -1.0 } },
    .{ .pos = .{ .x = -1.1920928955078125e-07, .y = -1.0, .z = -1.1920928955078125e-07 } },
    .{ .pos = .{ .x = -1.0, .y = -1.1920928955078125e-07, .z = -1.1920928955078125e-07 } },
    .{ .pos = .{ .x = -1.1920928955078125e-07, .y = -1.1920928955078125e-07, .z = 1.0 } },
    .{ .pos = .{ .x = -1.1920928955078125e-07, .y = 1.0, .z = -1.1920928955078125e-07 } },
    .{ .pos = .{ .x = 1.0, .y = -1.1920928955078125e-07, .z = -1.1920928955078125e-07 } },
    .{ .pos = .{ .x = -0.6666668057441711, .y = -0.6666667461395264, .z = -0.6666667461395264 } },
    .{ .pos = .{ .x = -0.6666668057441711, .y = -0.6666667461395264, .z = 0.6666667461395264 } },
    .{ .pos = .{ .x = -0.6666667461395264, .y = 0.6666668057441711, .z = -0.6666667461395264 } },
    .{ .pos = .{ .x = -0.6666668057441711, .y = 0.6666667461395264, .z = 0.6666667461395264 } },
    .{ .pos = .{ .x = 0.6666667461395264, .y = -0.6666668057441711, .z = -0.6666667461395264 } },
    .{ .pos = .{ .x = 0.6666668057441711, .y = -0.6666667461395264, .z = 0.6666667461395264 } },
    .{ .pos = .{ .x = 0.6666668057441711, .y = 0.6666667461395264, .z = -0.6666667461395264 } },
    .{ .pos = .{ .x = 0.6666667461395264, .y = 0.6666668057441711, .z = 0.6666667461395264 } },
};

var oct_inds = [_]u32{ 0, 1, 6, 1, 3, 7, 0, 2, 8, 3, 4, 9, 0, 5, 10, 3, 1, 11, 0, 4, 12, 3, 5, 13, 1, 2, 6, 2, 0, 6, 3, 2, 7, 2, 1, 7, 2, 4, 8, 4, 0, 8, 4, 2, 9, 2, 3, 9, 5, 1, 10, 1, 0, 10, 1, 5, 11, 5, 3, 11, 4, 5, 12, 5, 0, 12, 5, 4, 13, 4, 3, 13 };

var quad_inds = [_]u32{ 0, 1, 2, 0, 3, 1 };

var vkb: BaseDispatch = undefined;
var vki: InstanceDispatch = undefined;
var instance: vk.Instance = undefined;
var surface: vk.SurfaceKHR = undefined;
var messenger: vk.DebugUtilsMessengerEXT = undefined;
var device: Device = undefined;
var swapchain: Swapchain = undefined;
var renderpass: RenderPass = undefined;

/// monotonically increasing frame number
var frame_number: usize = 0;

/// index of the image in the swapchain we are currently
/// rendering to
var image_index: usize = 0;

/// Allocator used by the renderer
var allocator: Allocator = undefined;

/// Are we currently recreating the swapchain
/// I don't think this is really used yet but might
/// be useful when we multi thread
var recreating_swapchain = false;

/// generation of this resize
var size_gen: usize = 0;
var last_size_gen: usize = 0;

/// cached dimensions of the framebuffer
var cached_width: u32 = 0;
var cached_height: u32 = 0;

/// current dimesnsions of the framebuffer
var fb_width: u32 = 0;
var fb_height: u32 = 0;

/// Shader currently used by the pipeline
var shader: Shader = undefined;

/// pipeline currently being used
var pipeline: Pipeline = undefined;

/// framebuffer for render target
var framebuffers: []vk.Framebuffer = undefined;

/// the GPU side buffers that store the currenlty rendering objects
var vert_buf: Buffer = undefined;
var ind_buf: Buffer = undefined;

const MAX_FRAMES = 2;
/// The currently rendering frames
var frames: [MAX_FRAMES]FrameData = undefined;

/// descriptor set layout for global data (i.e. camera transform)
var global_descriptor_layout: vk.DescriptorSetLayout = .null_handle;
/// pool from which we allocate all descriptor sets
var global_descriptor_pool: vk.DescriptorPool = .null_handle;

const MeshPushConstants = struct {
    index: u32,
};

const CameraData = struct {
    projection: Mat4 = Mat4.perspective(mmath.util.rad(70), 800.0 / 600.0, 0.1, 1000),
    // projection: Mat4 = Mat4.ortho(0, 800.0, 0, 600.0, -100, 100),
    view: Mat4 = Mat4.translate(.{ .x = 0, .y = 0, .z = 10 }).inv(),
    // view: Mat4 = Mat4.translate(.{ .x = 0, .y = 0, .z = 0 }),
};

/// buffer for global shader data (rn just the camera matricies)
var global_buffer: Buffer = undefined;
/// camera matricies
var cam_data = CameraData{};
/// buffer for the model matricies of objects
var model_buffer: Buffer = undefined;
/// cpu side storage for all the model matricies
var model_data: [10]Mat4 = undefined;

/// descriptor set for the main shader
var global_descriptor_sets: [MAX_FRAMES]vk.DescriptorSet = undefined;

// initialize the renderer
// TODO: should this take in a surface instead of a window?
pub fn init(provided_allocator: Allocator, app_name: [*:0]const u8, window: Platform.Window) !void {
    allocator = provided_allocator;
    // open vulkan dynlib
    // TODO: make local or whatever
    var vk_proc = Platform.getInstanceProcAddress();

    // get proc address from glfw window
    //const vk_proc = Platform.getInstanceProcAddress();
    // load the base dispatch functions
    vkb = try BaseDispatch.load(vk_proc);

    //const winsize = try Platform.getWinSize();
    cached_width = 0;
    cached_height = 0;

    fb_width = if (cached_width != 0) cached_width else 800;
    fb_height = if (cached_height != 0) cached_height else 600;
    cached_width = 0;
    cached_height = 0;

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
        .enabled_extension_count = @intCast(u32, Platform.required_exts.len),
        .pp_enabled_extension_names = @ptrCast([*]const [*:0]const u8, &Platform.required_exts),
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
    surface = try Platform.createWindowSurface(vki, instance, window);
    errdefer vki.destroySurfaceKHR(instance, surface, null);

    // create a device
    // load dispatch functions which require device
    device = try Device.init(.{
        .graphics = true,
        .present = true,
        .transfer = false,
        .discrete = false,
        .compute = false,
    }, instance, vki, surface, allocator);
    errdefer device.deinit();

    swapchain = try Swapchain.init(vki, device, surface, fb_width, fb_height, allocator);
    errdefer swapchain.deinit(device, allocator);

    // subscribe to resize events
    try Events.register(Events.EventType.WindowResize, resize);

    // create a renderpass
    renderpass = try RenderPass.init(swapchain, device, .{ .offset = .{ .x = 0, .y = 0 }, .extent = .{
        .width = fb_width,
        .height = fb_height,
    } }, .{
        .color = true,
        .depth = true,
        .stencil = true,
    }, .{ 0, 0, 0.1, 1 }, 1.0, 0);
    errdefer renderpass.deinit(device);

    // create framebuffers
    std.log.info("fbw: {} fbh: {}", .{ fb_width, fb_width });
    framebuffers = try allocator.alloc(vk.Framebuffer, swapchain.img_count);
    for (framebuffers) |*fb| {
        fb.* = .null_handle;
    }
    try recreateFramebuffers();

    // create some buffers
    try createBuffers();

    // create frame objects
    try createDescriptors();

    // allocate the sets
    const layouts = [_]vk.DescriptorSetLayout{global_descriptor_layout};

    // create the descriptor set
    for (global_descriptor_sets) |*gs| {
        try device.vkd.allocateDescriptorSets(device.logical, &.{
            .descriptor_pool = global_descriptor_pool,
            .descriptor_set_count = 1,
            .p_set_layouts = layouts[0..],
        }, @ptrCast([*]vk.DescriptorSet, gs));
    }

    for (frames) |*f, i| {
        f.* = try FrameData.init(device, i);
    }

    // create shader
    shader = try Shader.init(device, allocator);

    // create pipeline
    try createPipeline();

    // upload the vertices
    // try upload(device.command_pool, vert_buf, Vertex, &quad_verts);
    // try upload(device.command_pool, ind_buf, u32, &quad_inds);
    try upload(device.command_pool, vert_buf, Vertex, &oct_verts);
    try upload(device.command_pool, ind_buf, u32, &oct_inds);

    // create buffers
}

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

// shutdown the renderer
pub fn deinit() void {

    // wait until rendering is done
    device.vkd.deviceWaitIdle(device.logical) catch {
        unreachable;
    };

    destroyBuffers();
    pipeline.deinit(device);

    shader.deinit(device);

    for (frames) |*f| {
        f.deinit(device);
    }

    device.vkd.destroyDescriptorPool(device.logical, global_descriptor_pool, null);
    device.vkd.destroyDescriptorSetLayout(device.logical, global_descriptor_layout, null);

    renderpass.deinit(device);
    swapchain.deinit(device, allocator);
    destroyFramebuffers();
    allocator.free(framebuffers);

    device.deinit();

    vki.destroySurfaceKHR(instance, surface, null);

    vki.destroyDebugUtilsMessengerEXT(instance, messenger, null);
    vki.destroyInstance(instance, null);
}

pub fn resize(ev: Events.Event) void {
    // TODO: make this only happen when 30 frames have passed since last resize event
    const w = ev.WindowResize.w;
    const h = ev.WindowResize.h;
    cached_width = w;
    cached_height = h;
    size_gen += 1;
    std.log.warn("resize triggered: {}x{}, gen: {}", .{ w, h, size_gen });
}

// TODO: move to render target stuff
pub fn recreateFramebuffers() !void {
    destroyFramebuffers();
    std.log.info("fbw: {} fbh: {}", .{ fb_width, fb_height });
    for (swapchain.images) |img, i| {
        const attachments = [_]vk.ImageView{ img.view, swapchain.depth.view };

        framebuffers[i] = try device.vkd.createFramebuffer(device.logical, &.{
            .flags = .{},
            .render_pass = renderpass.handle,
            .attachment_count = attachments.len,
            .p_attachments = @ptrCast([*]const vk.ImageView, &attachments),
            .width = fb_width,
            .height = fb_height,
            .layers = 1,
        }, null);
    }
}

pub fn destroyFramebuffers() void {
    for (framebuffers) |*fb| {
        if (fb.* != .null_handle) {
            device.vkd.destroyFramebuffer(device.logical, fb.*, null);
            fb.* = .null_handle;
        }
    }
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
    //std.log.debug("image idx: {}", .{image_index});

    var cb: *CommandBuffer = &getCurrentFrame().cmdbuf;
    cb.reset();
    try cb.begin(device, .{});

    // set the viewport
    const viewport = vk.Viewport{ .x = 0, .y = @intToFloat(f32, fb_height), .width = @intToFloat(f32, fb_width), .height = -@intToFloat(f32, fb_height), .min_depth = 0, .max_depth = 1 };
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

    // --------

    renderpass.begin(device, cb, framebuffers[image_index]);

    device.vkd.cmdBindPipeline(cb.handle, .graphics, pipeline.handle);

    return true;
}

pub fn endFrame() !void {
    var cb: *CommandBuffer = &getCurrentFrame().cmdbuf;

    // this stuff should be in a middle area where we are actually drawing the frame

    // this is some material system shit
    try updateDescriptorSets();
    device.vkd.cmdBindDescriptorSets(
        cb.handle,
        .graphics,
        pipeline.layout,
        0,
        1,
        @ptrCast([*]const vk.DescriptorSet, &global_descriptor_sets[getCurrentFrame().index]),
        0,
        undefined,
    );

    const offset = [_]vk.DeviceSize{0};
    device.vkd.cmdBindVertexBuffers(cb.handle, 0, 1, @ptrCast([*]const vk.Buffer, &vert_buf.handle), &offset);
    device.vkd.cmdBindIndexBuffer(cb.handle, ind_buf.handle, 0, .uint32);

    // push some constants to this bih
    device.vkd.cmdPushConstants(cb.handle, pipeline.layout, .{ .vertex_bit = true }, 0, @intCast(u32, @sizeOf(MeshPushConstants)), &MeshPushConstants{
        .index = 0,
    });

    device.vkd.cmdDrawIndexed(cb.handle, oct_inds.len, 1, 0, 0, 0);

    renderpass.end(device, cb);
    // --------

    try cb.end(device);

    // wait for the previous frame?

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

    try swapchain.recreate(vki, device, surface, cached_width, cached_height, allocator);

    fb_width = cached_width;
    fb_height = cached_height;

    cached_width = 0;
    cached_height = 0;

    last_size_gen = size_gen;

    // destroy the sync objects
    for (frames) |*f| {
        f.render_fence.deinit(device);
        f.cmdbuf.deinit(device, device.command_pool);
    }

    // create the framebuffers
    try recreateFramebuffers();

    // create the command buffers
    for (frames) |*f| {
        f.render_fence = try Fence.init(device, true);
        f.cmdbuf = try CommandBuffer.init(device, device.command_pool, true);
    }

    // reset the renderpass
    renderpass.render_area = .{ .offset = .{ .x = 0, .y = 0 }, .extent = .{
        .width = fb_width,
        .height = fb_height,
    } };

    recreating_swapchain = false;
    std.log.info("done recreating swapchain", .{});

    //frame_number += 1;

    return true;
}

// TODO: move this?
fn createBuffers() !void {
    const vertex_buf_size = @sizeOf(Vertex) * 1024 * 1024;
    vert_buf = try Buffer.init(device, vertex_buf_size, .{
        .vertex_buffer_bit = true,
        .transfer_src_bit = true,
        .transfer_dst_bit = true,
    }, .{ .device_local_bit = true }, true);

    const index_buf_size = @sizeOf(u32) * 1024 * 1024;
    ind_buf = try Buffer.init(device, index_buf_size, .{
        .index_buffer_bit = true,
        .transfer_src_bit = true,
        .transfer_dst_bit = true,
    }, .{ .device_local_bit = true }, true);

    global_buffer = try Buffer.init(device, @sizeOf(CameraData), .{ .transfer_dst_bit = true, .uniform_buffer_bit = true }, .{
        .host_visible_bit = true,
        .host_coherent_bit = true,
    }, true);

    model_buffer = try Buffer.init(device, @sizeOf(@TypeOf(model_data)), .{
        .storage_buffer_bit = true,
        .transfer_dst_bit = true,
    }, .{
        .host_visible_bit = true,
        .host_coherent_bit = true,
    }, true);
}

fn destroyBuffers() void {
    vert_buf.deinit(device);
    ind_buf.deinit(device);
    global_buffer.deinit(device);
    model_buffer.deinit(device);
}

// TODO: find a home for this
fn createPipeline() !void {
    const viewport = vk.Viewport{ .x = 0, .y = @intToFloat(f32, fb_height), .width = @intToFloat(f32, fb_width), .height = -@intToFloat(f32, fb_height), .min_depth = 0, .max_depth = 1 };

    const scissor = vk.Rect2D{
        .offset = .{ .x = 0, .y = 0 },
        .extent = .{
            .width = fb_width,
            .height = fb_height,
        },
    };

    pipeline = try Pipeline.init(device, renderpass, &[_]vk.DescriptorSetLayout{global_descriptor_layout}, &[_]vk.PushConstantRange{.{
        .stage_flags = .{ .vertex_bit = true },
        .offset = 0,
        .size = @intCast(u32, @sizeOf(MeshPushConstants)),
    }}, &shader.stage_ci, viewport, scissor, false);
}

fn upload(pool: vk.CommandPool, buffer: Buffer, comptime T: type, items: []T) !void {
    const size = @sizeOf(T) * items.len;
    const staging_buffer = try Buffer.init(
        device,
        size,
        .{ .transfer_src_bit = true },
        .{ .host_visible_bit = true, .host_coherent_bit = true },
        true,
    );
    defer staging_buffer.deinit(device);

    try staging_buffer.load(device, T, items, 0);

    try Buffer.copyTo(device, pool, device.graphics.?, staging_buffer, 0, buffer, 0, size);
}

fn createDescriptors() !void {
    // create a descriptor pool for the frame data
    const sizes = [_]vk.DescriptorPoolSize{
        .{
            .@"type" = .uniform_buffer,
            .descriptor_count = frames.len,
        },
        .{
            .@"type" = .storage_buffer,
            .descriptor_count = frames.len,
        },
    };

    global_descriptor_pool = try device.vkd.createDescriptorPool(device.logical, &.{
        .flags = .{},
        .max_sets = frames.len,
        .pool_size_count = sizes.len,
        .p_pool_sizes = &sizes,
    }, null);

    // attempt at bindless aproach
    const global_bindings = [_]vk.DescriptorSetLayoutBinding{
        // camera
        .{
            .binding = 0,
            .descriptor_type = .uniform_buffer,
            .descriptor_count = 1,
            .stage_flags = .{ .vertex_bit = true },
            .p_immutable_samplers = null,
        },
        // storage for model matricies
        .{
            .binding = 1,
            .descriptor_type = .storage_buffer,
            .descriptor_count = 1,
            .stage_flags = .{ .vertex_bit = true },
            .p_immutable_samplers = null,
        },
    };

    global_descriptor_layout = try device.vkd.createDescriptorSetLayout(device.logical, &.{
        .flags = .{},
        .binding_count = global_bindings.len,
        .p_bindings = &global_bindings,
    }, null);
}

fn updateDescriptorSets() !void {
    try global_buffer.load(device, CameraData, &[_]CameraData{cam_data}, 0);
    try model_buffer.load(device, Mat4, model_data[0..], 0);

    const cam_infos = [_]vk.DescriptorBufferInfo{
        .{
            .buffer = global_buffer.handle,
            .offset = 0,
            .range = @sizeOf(CameraData),
        },
    };
    const model_infos = [_]vk.DescriptorBufferInfo{
        .{
            .buffer = model_buffer.handle,
            .offset = 0,
            .range = @sizeOf(@TypeOf(model_data)),
        },
    };

    const writes = [_]vk.WriteDescriptorSet{ .{
        .dst_set = global_descriptor_sets[getCurrentFrame().index],
        .dst_binding = 0,
        .dst_array_element = 0,
        .descriptor_count = cam_infos.len,
        .descriptor_type = .uniform_buffer,
        .p_image_info = undefined,
        .p_buffer_info = cam_infos[0..],
        .p_texel_buffer_view = undefined,
    }, .{
        .dst_set = global_descriptor_sets[getCurrentFrame().index],
        .dst_binding = 1,
        .dst_array_element = 0,
        .descriptor_count = model_infos.len,
        .descriptor_type = .storage_buffer,
        .p_image_info = undefined,
        .p_buffer_info = model_infos[0..],
        .p_texel_buffer_view = undefined,
    } };

    device.vkd.updateDescriptorSets(device.logical, writes.len, &writes, 0, undefined);
}

pub fn updateUniform(transform: Mat4) !void {
    model_data[0] = transform;
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
