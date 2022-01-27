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

/// Keeps the state of the renderer and dispatch functions
const Context = struct {
    vkb: BaseDispatch = undefined,
    vki: InstanceDispatch = undefined,

    instance: vk.Instance = undefined,
    surface: vk.SurfaceKHR = undefined,
    messenger: vk.DebugUtilsMessengerEXT = undefined,
    device: Device = undefined,
    swapchain: Swapchain = undefined,
};

// TODO: set this in a config
const required_layers = [_][*:0]const u8{"VK_LAYER_KHRONOS_validation"};

// setup the context
var context: Context = .{};

var renderpass: RenderPass = undefined;

var graphics_buffers: []CommandBuffer = undefined;

// initialize the renderer
pub fn init(allocator: Allocator, app_name: [*:0]const u8, window: glfw.Window, extent: vk.Extent2D) !void {
    // get proc address from glfw window
    // TODO: this should really just be a function passed into the init
    const vk_proc = @ptrCast(fn (instance: vk.Instance, procname: [*:0]const u8) callconv(.C) vk.PfnVoidFunction, glfw.getInstanceProcAddress);

    // load the base dispatch functions
    context.vkb = try BaseDispatch.load(vk_proc);

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
    context.instance = try context.vkb.createInstance(&.{
        .flags = .{},
        .p_application_info = &app_info,
        .enabled_layer_count = required_layers.len,
        .pp_enabled_layer_names = &required_layers,
        .enabled_extension_count = @intCast(u32, required_exts.len),
        .pp_enabled_extension_names = @ptrCast([*]const [*:0]const u8, &required_exts),
    }, null);

    // load dispatch functions which require instance
    context.vki = try InstanceDispatch.load(context.instance, vk_proc);
    errdefer context.vki.destroyInstance(context.instance, null);

    // setup debug msg
    context.messenger = try context.vki.createDebugUtilsMessengerEXT(
        context.instance,
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
    errdefer context.vki.destroyDebugUtilsMessengerEXT(context.instance, context.messenger, null);

    // TODO: move this to system
    if ((try glfw.createWindowSurface(context.instance, window, null, &context.surface)) != @enumToInt(vk.Result.success)) {
        return error.SurfaceInitFailed;
    }
    errdefer context.vki.destroySurfaceKHR(context.instance, context.surface, null);

    // create a device
    // load dispatch functions which require device
    context.device = try Device.init(.{}, context.instance, context.vki, context.surface, allocator);
    errdefer context.device.deinit();

    context.swapchain = try Swapchain.init(context.vki, context.device, context.surface, extent, allocator);
    errdefer context.swapchain.deinit(context.device, allocator);

    // try to recreate for fun
    try context.swapchain.recreate(context.vki, context.device, context.surface, allocator);

    // create a renderpass
    renderpass = try RenderPass.init(context.swapchain, context.device, .{
        .color = true,
    });
    errdefer renderpass.deinit(context.device);

    // create a command pool

    // allocate command buffers
    graphics_buffers = try allocator.alloc(CommandBuffer, context.swapchain.images.len);
    errdefer allocator.free(graphics_buffers);

    for (graphics_buffers) |*cb| {
        cb.* = try CommandBuffer.init(context.device, context.device.command_pool, true);
    }

    // create framebuffers
    try recreateFramebuffers();

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

    for (context.swapchain.framebuffers) |fb| {
        // TODO: this will need another attachment for depth
        context.device.vkd.destroyFramebuffer(context.device.logical, fb, null);
    }

    for (graphics_buffers) |*cb| {
        cb.deinit(context.device, context.device.command_pool);
    }
    renderpass.deinit(context.device);
    context.swapchain.deinit(context.device, allocator);

    context.device.deinit();

    context.vki.destroySurfaceKHR(context.instance, context.surface, null);

    context.vki.destroyDebugUtilsMessengerEXT(context.instance, context.messenger, null);
    context.vki.destroyInstance(context.instance, null);
}

// TODO: fix this, i'm lazy
// also should probably be in the swapchain??
pub fn recreateFramebuffers() !void {
    for (context.swapchain.images) |img, i| {
        // TODO: this will need another attachment for depth
        context.swapchain.framebuffers[i] = try context.device.vkd.createFramebuffer(context.device.logical, &.{
            .flags = .{},
            .render_pass = renderpass.handle,
            .attachment_count = 1,
            .p_attachments = @ptrCast([*]const vk.ImageView, &img.view),
            .width = context.swapchain.extent.width,
            .height = context.swapchain.extent.height,
            .layers = 1,
        }, null);
    }
}
