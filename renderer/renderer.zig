const dispatch_types = @import("dispatch_types.zig");
const BaseDispatch = dispatch_types.BaseDispatch;
const InstanceDispatch = dispatch_types.InstanceDispatch;
const std = @import("std");
const builtin = @import("builtin");
const vk = @import("vulkan");
const glfw = @import("glfw");
const Allocator = std.mem.Allocator;

const Device = @import("device.zig").Device;
const Swapchain = @import("swapchain.zig").Swapchain;
const RenderPass = @import("renderpass.zig").RenderPass;
const CommandBuffer = @import("commandbuffer.zig").CommandBuffer;
const Fence = @import("fence.zig").Fence;
const Semaphore = @import("semaphore.zig").Semaphore;
const Shader = @import("shader.zig").Shader;
const Pipeline = @import("pipeline.zig").Pipeline;
const Vertex = @import("pipeline.zig").Vertex;

// TODO: get these from the system
const required_exts = [_][*:0]const u8{
    vk.extension_info.ext_debug_utils.name,
    "VK_KHR_surface",
    switch (builtin.target.os.tag) {
        .macos => "VK_EXT_metal_surface",
        .linux => "VK_KHR_xcb_surface",
        else => unreachable,
    },
};

// TODO: set this in a config
const required_layers = [_][*:0]const u8{"VK_LAYER_KHRONOS_validation"};

var vkb: BaseDispatch = undefined;
var vki: InstanceDispatch = undefined;
var instance: vk.Instance = undefined;
var surface: vk.SurfaceKHR = undefined;
var messenger: vk.DebugUtilsMessengerEXT = undefined;
var device: Device = undefined;
var swapchain: Swapchain = undefined;
var renderpass: RenderPass = undefined;
var graphics_buffers: []CommandBuffer = undefined;

// TODO: find somewhere for these to live
var image_avail_semaphores: []Semaphore = undefined;
var queue_complete_semaphores: []Semaphore = undefined;

var in_flight_fences: []Fence = undefined;
var images_in_flight: []Fence = undefined;

var current_frame: usize = 0;
var image_index: usize = 0;

var allocator: Allocator = undefined;

var recreating_swapchain = false;

var size_gen: usize = 0;
var last_size_gen: usize = 0;

var cached_width: u32 = 0;
var cached_height: u32 = 0;

var fb_width: u32 = 0;
var fb_height: u32 = 0;

var shader: Shader = undefined;

var pipeline: Pipeline = undefined;

// initialize the renderer
pub fn init(provided_allocator: Allocator, app_name: [*:0]const u8, window: glfw.Window) !void {
    allocator = provided_allocator;


    // get proc address from glfw window
    // TODO: this should really just be a function passed into the init
    const vk_proc = @ptrCast(fn (instance: vk.Instance, procname: [*:0]const u8) callconv(.C) vk.PfnVoidFunction, glfw.getInstanceProcAddress);

    // load the base dispatch functions
    vkb = try BaseDispatch.load(vk_proc);

    const winsize = try window.getSize();
    cached_width = winsize.width;
    cached_height = winsize.height;

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
        .enabled_extension_count = @intCast(u32, required_exts.len),
        .pp_enabled_extension_names = @ptrCast([*]const [*:0]const u8, &required_exts),
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
    if ((try glfw.createWindowSurface(instance, window, null, &surface)) != @enumToInt(vk.Result.success)) {
        return error.SurfaceInitFailed;
    }
    errdefer vki.destroySurfaceKHR(instance, surface, null);

    // create a device
    // load dispatch functions which require device
    device = try Device.init(.{}, instance, vki, surface, allocator);
    errdefer device.deinit();

    swapchain = try Swapchain.init(vki, device, surface, fb_width, fb_height, allocator);
    errdefer swapchain.deinit(device, allocator);

    // create a renderpass
    renderpass = try RenderPass.init(swapchain, device, .{ .offset = .{ .x = 0, .y = 0 }, .extent = .{
        .width = fb_width,
        .height = fb_height,
    } }, .{
        .color = true,
    }, .{ 0, 0, 0.1, 1 });
    errdefer renderpass.deinit(device);

    // create a command pool

    // allocate command buffers
    graphics_buffers = try allocator.alloc(CommandBuffer, swapchain.images.len);
    errdefer allocator.free(graphics_buffers);

    for (graphics_buffers) |*cb| {
        cb.* = try CommandBuffer.init(device, device.command_pool, true);
    }

    // create framebuffers
    std.log.info("fbw: {} fbh: {}", .{ fb_width, fb_width });
    try recreateFramebuffers();

    // create sync objects
    image_avail_semaphores = try allocator.alloc(Semaphore, swapchain.images.len - 1);
    queue_complete_semaphores = try allocator.alloc(Semaphore, swapchain.images.len - 1);
    in_flight_fences = try allocator.alloc(Fence, swapchain.images.len - 1);

    images_in_flight = try allocator.alloc(Fence, swapchain.images.len);

    for (image_avail_semaphores) |*s| {
        s.* = try Semaphore.init(device);
        errdefer s.deinit(device);
    }

    for (queue_complete_semaphores) |*s| {
        s.* = try Semaphore.init(device);
        errdefer s.deinit(device);
    }

    for (in_flight_fences) |*f| {
        // TODO: should this be signaled
        f.* = try Fence.init(device, true);
        errdefer f.deinit(device);
    }

    for (images_in_flight) |*f| {
        f.* = Fence{};
    }


    // create shader
    shader = try Shader.init(device, allocator);

    // create pipeline
    try createPipeline();
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

    const vertex_attribute_description = [_]vk.VertexInputAttributeDescription{
        .{
            .binding = 0,
            .location = 0,
            .format = .r32g32_sfloat,
            .offset = @offsetOf(Vertex, "pos"),
        },
    };

    pipeline = try Pipeline.init(
        device,
        renderpass,
        &vertex_attribute_description,
        &[_]vk.DescriptorSetLayout{},
        &shader.stage_ci,
        viewport,
        scissor,
        false
    );
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

    pipeline.deinit(device);

    shader.deinit(device);

    // wait until rendering is done
    device.vkd.deviceWaitIdle(device.logical) catch {
        unreachable;
    };

    for (image_avail_semaphores) |s| {
        s.deinit(device);
    }

    for (queue_complete_semaphores) |s| {
        s.deinit(device);
    }

    for (in_flight_fences) |f| {
        f.deinit(device);
    }

    for (graphics_buffers) |*cb| {
        cb.deinit(device, device.command_pool);
    }
    renderpass.deinit(device);
    swapchain.deinit(device, allocator);

    device.deinit();

    vki.destroySurfaceKHR(instance, surface, null);

    vki.destroyDebugUtilsMessengerEXT(instance, messenger, null);
    vki.destroyInstance(instance, null);
}

pub fn resize(w: u32, h: u32) void {
    cached_width = w;
    cached_height = h;
    size_gen += 1;
    std.log.warn("resize triggered: {}x{}, gen: {}", .{ w, h, size_gen });
}

// TODO: fix this, i'm lazy
// also should probably be in the swapchain??
pub fn recreateFramebuffers() !void {
    std.log.info("fbw: {} fbh: {}", .{ fb_width, fb_height });
    for (swapchain.images) |img, i| {
        // TODO: this will need another attachment for depth
        swapchain.framebuffers[i] = try device.vkd.createFramebuffer(device.logical, &.{
            .flags = .{},
            .render_pass = renderpass.handle,
            .attachment_count = 1,
            .p_attachments = @ptrCast([*]const vk.ImageView, &img.view),
            .width = fb_width,
            .height = fb_height,
            .layers = 1,
        }, null);
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
    try in_flight_fences[current_frame].wait(device, std.math.maxInt(u64));

    image_index = swapchain.acquireNext(device, image_avail_semaphores[current_frame], Fence{}) catch |err| {
        switch (err) {
            error.OutOfDateKHR => {
                std.log.warn("failed to aquire, booting", .{});
                //_ = try recreateSwapchain();
                return false;
            },
            else => |narrow| return narrow,
        }
    };

    const cb: *CommandBuffer = &graphics_buffers[image_index];
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

    renderpass.begin(device, cb, swapchain.framebuffers[image_index]);

    return true;
}

pub fn endFrame() !void {
    const cb: *CommandBuffer = &graphics_buffers[image_index];
    renderpass.end(device, cb);
    try cb.end(device);

    // make sure the previous frame isn't using this image
    if (images_in_flight[image_index].handle != vk.Fence.null_handle) {
        try images_in_flight[image_index].wait(device, std.math.maxInt(u64));
    }

    // this one is in flight
    images_in_flight[image_index] = in_flight_fences[current_frame];

    // reset the fence
    try in_flight_fences[current_frame].reset(device);

    // submit it

    // waits for the this stage to write
    const wait_stage = [_]vk.PipelineStageFlags{.{ .color_attachment_output_bit = true }};

    try device.vkd.queueSubmit(device.graphics.?.handle, 1, &[_]vk.SubmitInfo{.{
        .command_buffer_count = 1,
        .p_command_buffers = @ptrCast([*]const vk.CommandBuffer, &cb.handle),

        // signaled when queue is complete
        .signal_semaphore_count = 1,
        .p_signal_semaphores = queue_complete_semaphores[current_frame].ptr(),

        // wait for this before we start
        .wait_semaphore_count = 1,
        .p_wait_semaphores = image_avail_semaphores[current_frame].ptr(),

        .p_wait_dst_stage_mask = &wait_stage,
    }}, in_flight_fences[current_frame].handle);

    cb.updateSubmitted();

    // present that shit
    // TODO: use the swapchain state
    swapchain.present(device, device.present.?, queue_complete_semaphores[current_frame], @intCast(u32, image_index)) catch |err| {
        switch (err) {
            error.SuboptimalKHR, error.OutOfDateKHR => {
                std.log.warn("swapchain out of date in end frame", .{});
                //_ = try recreateSwapchain();
            },
            else => |narrow| return narrow,
        }
    };

    current_frame = (current_frame + 1) % (swapchain.images.len - 1);
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

    // reset images in flight
    for (images_in_flight) |*f| {
        f.* = Fence{};
    }

    try swapchain.recreate(vki, device, surface, cached_width, cached_height, allocator);

    fb_width = cached_width;
    fb_height = cached_height;

    cached_width = 0;
    cached_height = 0;

    last_size_gen = size_gen;

    // destroy the command buffers
    for (graphics_buffers) |*cb| {
        cb.deinit(device, device.command_pool);
    }

    // create the framebuffers
    try recreateFramebuffers();

    // create the command buffers
    for (graphics_buffers) |*cb| {
        cb.* = try CommandBuffer.init(device, device.command_pool, true);
    }

    // reset the renderpass
    renderpass.render_area = .{ .offset = .{ .x = 0, .y = 0 }, .extent = .{
        .width = fb_width,
        .height = fb_height,
    } };

    recreating_swapchain = false;
    std.log.info("done recreating swapchain", .{});

    return true;
}
