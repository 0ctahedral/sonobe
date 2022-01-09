const std = @import("std");
const builtin = @import("builtin");
const vk = @import("vulkan");
const glfw = @import("glfw");
const Allocator = std.mem.Allocator;

const BaseDispatch = vk.BaseWrapper(&.{
    .createInstance,
});

const InstanceDispatch = vk.InstanceWrapper(&.{
    .createDebugUtilsMessengerEXT,
    .destroyInstance,
    .createDevice,
    .destroySurfaceKHR,
    .enumeratePhysicalDevices,
    .getPhysicalDeviceProperties,
    .enumerateDeviceExtensionProperties,
    .getPhysicalDeviceSurfaceFormatsKHR,
    .getPhysicalDeviceSurfacePresentModesKHR,
    .getPhysicalDeviceSurfaceCapabilitiesKHR,
    .getPhysicalDeviceQueueFamilyProperties,
    .getPhysicalDeviceSurfaceSupportKHR,
    .getPhysicalDeviceMemoryProperties,
    .getDeviceProcAddr,
});

const DeviceDispatch = vk.DeviceWrapper(&.{
    .destroyDevice,
    .getDeviceQueue,
    .createSemaphore,
    .createFence,
    .createImageView,
    .destroyImageView,
    .destroySemaphore,
    .destroyFence,
    .getSwapchainImagesKHR,
    .createSwapchainKHR,
    .destroySwapchainKHR,
    .acquireNextImageKHR,
    .deviceWaitIdle,
    .waitForFences,
    .resetFences,
    .queueSubmit,
    .queuePresentKHR,
    .createCommandPool,
    .destroyCommandPool,
    .allocateCommandBuffers,
    .freeCommandBuffers,
    .queueWaitIdle,
    .createShaderModule,
    .destroyShaderModule,
    .createPipelineLayout,
    .destroyPipelineLayout,
    .createRenderPass,
    .destroyRenderPass,
    .createGraphicsPipelines,
    .destroyPipeline,
    .createFramebuffer,
    .destroyFramebuffer,
    .beginCommandBuffer,
    .endCommandBuffer,
    .allocateMemory,
    .freeMemory,
    .createBuffer,
    .destroyBuffer,
    .getBufferMemoryRequirements,
    .mapMemory,
    .unmapMemory,
    .bindBufferMemory,
    .cmdBeginRenderPass,
    .cmdEndRenderPass,
    .cmdBindPipeline,
    .cmdDraw,
    .cmdSetViewport,
    .cmdSetScissor,
    .cmdBindVertexBuffers,
    .cmdCopyBuffer,
});

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

var vkb: BaseDispatch = undefined;
var vki: InstanceDispatch = undefined;
var vkd: DeviceDispatch = undefined;

var instance: vk.Instance = undefined;

const Self = @This();

// initialize the renderer
pub fn init(allocator: Allocator, app_name: [*:0]const u8, window: glfw.Window) !void {
    // get proc address from glfw window
    // TODO: this should really just be a function passed into the init
    const vk_proc = @ptrCast(fn (instance: vk.Instance, procname: [*:0]const u8) callconv(.C) vk.PfnVoidFunction, glfw.getInstanceProcAddress);

    // load the base dispatch functions
    vkb = try BaseDispatch.load(vk_proc);

    _ = window;
    _ = allocator;

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
        .enabled_layer_count = 0,
        .pp_enabled_layer_names = undefined,
        .enabled_extension_count = @intCast(u32, required_exts.len),
        .pp_enabled_extension_names = @ptrCast([*]const [*:0]const u8, &required_exts),
    }, null);

    // load dispatch functions which require instance
    vki = try InstanceDispatch.load(instance, vk_proc);
    errdefer vki.destroyInstance(instance, null);

    // create a device
    // load dispatch functions which require device
}

// shutdown the renderer
pub fn deinit() void {
    //vkd.destroyDevice(device, null);
    //vki.destroySurfaceKHR(instance, surface, null);
    vki.destroyInstance(instance, null);
}
