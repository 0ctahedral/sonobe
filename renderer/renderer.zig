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
var image_avail_semaphores: []vk.Semaphore = undefined;
var queue_complete_semaphores: []vk.Semaphore = undefined;

var in_flight_fences: []vk.Fence = undefined;
var images_in_flight: []vk.Fence = undefined;

var current_frame: usize = 0;
var image_index: usize = 0;

// initialize the renderer
pub fn init(allocator: Allocator, app_name: [*:0]const u8, window: glfw.Window, extent: vk.Extent2D) !void {
    // get proc address from glfw window
    // TODO: this should really just be a function passed into the init
    const vk_proc = @ptrCast(fn (instance: vk.Instance, procname: [*:0]const u8) callconv(.C) vk.PfnVoidFunction, glfw.getInstanceProcAddress);

    // load the base dispatch functions
    vkb = try BaseDispatch.load(vk_proc);

    _ = window;

    const app_info = vk.ApplicationInfo{
        .p_application_name = app_name,
        .application_version = vk.makeApiVersion(0, 0, 0, 0),
        .p_engine_name = app_name,
        .engine_version = vk.makeApiVersion(0, 0, 0, 0),
        .api_version = vk.API_VERSION_1_2,
    };

    // TODO: query validation layers

    // create an instance
    instance = try vkb.createInstance(&.{
        .flags = .{},
        .p_application_info = &app_info,
        .enabled_layer_count = required_layers.len,
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

    swapchain = try Swapchain.init(vki, device, surface, extent, allocator);
    errdefer swapchain.deinit(device, allocator);

    // try to recreate for fun
    try swapchain.recreate(vki, device, surface, allocator);

    // create a renderpass
    renderpass = try RenderPass.init(
        swapchain,
        device,
        .{ .offset = .{ .x = 0, .y = 0}, .extent = extent },
        .{ .color = true, },
        .{0, 1, 0, 1}
    );
    errdefer renderpass.deinit(device);

    // create a command pool

    // allocate command buffers
    graphics_buffers = try allocator.alloc(CommandBuffer, swapchain.images.len);
    errdefer allocator.free(graphics_buffers);

    for (graphics_buffers) |*cb| {
        cb.* = try CommandBuffer.init(device, device.command_pool, true);
    }

    // create framebuffers
    try recreateFramebuffers();

    // create sync objects
    image_avail_semaphores = try allocator.alloc(vk.Semaphore, swapchain.images.len - 1);
    queue_complete_semaphores = try allocator.alloc(vk.Semaphore, swapchain.images.len - 1);
    in_flight_fences = try allocator.alloc(vk.Fence, swapchain.images.len - 1);

    images_in_flight = try allocator.alloc(vk.Fence, swapchain.images.len);

    for (image_avail_semaphores) |*s| {
        s.* = try device.vkd.createSemaphore(device.logical,  &.{ .flags = .{} }, null);
        errdefer device.vkd.destroySemaphore(device.logical, s, null);
    }

    for (queue_complete_semaphores) |*s| {
        s.* = try device.vkd.createSemaphore(device.logical,  &.{ .flags = .{} }, null);
        errdefer device.vkd.destroySemaphore(device.logical, s, null);
    }

    for (in_flight_fences) |*f| {
        // TODO: should this be signaled
        f.* = try device.vkd.createFence(device.logical, &.{ .flags = .{
            .signaled_bit = true
        } }, null);
        errdefer device.vkd.destroyFence(device.logical, f, null);
    }

    for (images_in_flight) |*f| {
        f.* = vk.Fence.null_handle;
    }

    // create pipeline
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
    return 1;
}

// shutdown the renderer
pub fn deinit(allocator: Allocator) void {

    // wait until rendering is done
    device.vkd.deviceWaitIdle(device.logical) catch {
        unreachable;
    };

    for (image_avail_semaphores) |s| {
        device.vkd.destroySemaphore(device.logical, s, null);
    }

    for (queue_complete_semaphores) |s| {
        device.vkd.destroySemaphore(device.logical, s, null);
    }

    for (in_flight_fences) |f| {
        device.vkd.destroyFence(device.logical, f, null);
    }

    for (swapchain.framebuffers) |fb| {
        // TODO: this will need another attachment for depth
        device.vkd.destroyFramebuffer(device.logical, fb, null);
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

// TODO: fix this, i'm lazy
// also should probably be in the swapchain??
pub fn recreateFramebuffers() !void {
    for (swapchain.images) |img, i| {
        // TODO: this will need another attachment for depth
        swapchain.framebuffers[i] = try device.vkd.createFramebuffer(device.logical, &.{
            .flags = .{},
            .render_pass = renderpass.handle,
            .attachment_count = 1,
            .p_attachments = @ptrCast([*]const vk.ImageView, &img.view),
            .width = swapchain.extent.width,
            .height = swapchain.extent.height,
            .layers = 1,
        }, null);
    }
}

pub fn beginFrame() !void {
    // TODO: state if we are waiting for swapchain resize
    // TODO: state if we need to resize

    // wait for current frame
    _ = try device.vkd.waitForFences(
        device.logical,
        1,
        @ptrCast([*]const vk.Fence, &in_flight_fences[current_frame]),
        vk.TRUE, std.math.maxInt(u64));

    image_index = try swapchain.acquireNext(device, image_avail_semaphores[current_frame], vk.Fence.null_handle);

    const cb: *CommandBuffer = &graphics_buffers[image_index];
    cb.reset();
    try cb.begin(device, .{});

    // set the viewport
    const viewport = vk.Viewport{
        .x = 0,
        .y = @intToFloat(f32, swapchain.extent.height),
        .width = @intToFloat(f32, swapchain.extent.width),
        .height = -@intToFloat(f32, swapchain.extent.height),
        .min_depth = 0,
        .max_depth = 1
    };
    device.vkd.cmdSetViewport(cb.handle, 0, 1, @ptrCast([*]const vk.Viewport, &viewport));

    // set the scissor (region we are clipping)
    const scissor = vk.Rect2D{
        .offset = .{ .x = 0, .y = 0 },
        .extent = swapchain.extent,
    };

    device.vkd.cmdSetScissor(cb.handle, 0, 1, @ptrCast([*]const vk.Rect2D, &scissor));


    renderpass.begin(device, cb, swapchain.framebuffers[image_index]);

    std.log.info("frame started!", .{});
}

pub fn endFrame() !void {
    const cb: *CommandBuffer = &graphics_buffers[image_index];
    renderpass.end(device, cb);
    try cb.end(device);


    // make sure the previous frame isn't using this image
    if (images_in_flight[image_index] != vk.Fence.null_handle) {
        _ = try device.vkd.waitForFences(
            device.logical,
            1,
            @ptrCast([*]const vk.Fence, &images_in_flight[image_index]),
            vk.TRUE, std.math.maxInt(u64));
    }

    // this one is in flight
    images_in_flight[image_index] = in_flight_fences[current_frame];

    // reset the fence
    try device.vkd.resetFences(device.logical, 1, @ptrCast([*]const vk.Fence, &in_flight_fences[current_frame]));

    // submit it

    // waits for the this stage to write
    const wait_stage = [_]vk.PipelineStageFlags{.{ .color_attachment_output_bit = true }};

    try device.vkd.queueSubmit(device.graphics.?.handle, 1,
        &[_]vk.SubmitInfo{.{
            .command_buffer_count = 1,
            .p_command_buffers = @ptrCast([*]const vk.CommandBuffer, &cb.handle),

            // signaled when queue is complete
            .signal_semaphore_count = 1,
            .p_signal_semaphores = @ptrCast([*]const vk.Semaphore, &queue_complete_semaphores[current_frame]),

            // wait for this before we start
            .wait_semaphore_count = 1,
            .p_wait_semaphores = @ptrCast([*]const vk.Semaphore, &image_avail_semaphores[current_frame]),

            .p_wait_dst_stage_mask = &wait_stage,
        }},
    in_flight_fences[current_frame]);

    cb.updateSubmitted();

    // present that shit
    // TODO: use the swapchain state 
    _ = try swapchain.present(device, device.present.?, queue_complete_semaphores[current_frame], @intCast(u32, image_index));


    std.log.info("frame ended!", .{});
}
