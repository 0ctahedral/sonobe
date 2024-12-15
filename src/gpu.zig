const std = @import("std");
const core = @import("core.zig");
pub const log = core.logger.Logger("gpu");

const device = @import("gpu/device.zig");
const Device = device.Device;
const pickPhysicalDevice = device.pickPhysicalDevice;

const Swapchain = @import("gpu/swapchain.zig");

const Allocator = std.mem.Allocator;

const vk = @import("vulkan");
const c = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_vulkan.h");
});

pub const apis: []const vk.ApiInfo = &.{
    // individual functions
    // .{
    //     .base_commands = .{
    //         .createInstance = true,
    //     },
    //     .instance_commands = .{
    //         .createDevice = true,
    //     },
    // },

    // feature sets
    vk.features.version_1_0,
    vk.extensions.khr_surface,
    vk.extensions.khr_swapchain,
};

const BaseDispatch = vk.BaseWrapper(apis);
const InstanceDispatch = vk.InstanceWrapper(apis);
pub const Instance = vk.InstanceProxy(apis);
const DeviceDispatch = vk.DeviceWrapper(apis);

const Self = @This();

pub var vki: InstanceDispatch = undefined;
pub var instance: Instance = undefined;
var vkd: DeviceDispatch = undefined;

pub fn init() !void {
    log.info("init", .{});

    if (!c.SDL_Vulkan_LoadLibrary(null)) {
        return error.CouldNotLoadVulkan;
    }

    const proc_addr: *const fn (instance: vk.Instance, procname: [*:0]const u8) vk.PfnVoidFunction = @ptrCast(c.SDL_Vulkan_GetVkGetInstanceProcAddr());
    var vkb: BaseDispatch = try BaseDispatch.load(proc_addr);

    const required_exts: []const [*:0]const u8 = &[_][*:0]const u8{
        vk.extensions.khr_surface.name,
        vk.extensions.ext_metal_surface.name,
        vk.extensions.khr_portability_enumeration.name,
    };

    log.debug("loading extensions:", .{});
    for (required_exts, 0..) |value, i| {
        log.debug("extension {}: {s}", .{ i, value });
    }

    const app_info = vk.ApplicationInfo{
        .application_version = vk.makeApiVersion(0, 0, 0, 0),
        .engine_version = vk.makeApiVersion(0, 0, 0, 0),
        .api_version = vk.API_VERSION_1_2,
    };

    const layers = &[_][*:0]const u8{
        // vk.extensions.khr_portability_enumeration.name
        // vk.extensions.ext_validation_features.name,
    };

    const vk_instance = try vkb.createInstance(&.{ .p_application_info = &app_info, .enabled_extension_count = required_exts.len, .pp_enabled_extension_names = @ptrCast(required_exts), .enabled_layer_count = layers.len, .pp_enabled_layer_names = @ptrCast(layers), .flags = .{ .enumerate_portability_bit_khr = true } }, null);

    vki = try InstanceDispatch.load(vk_instance, vkb.dispatch.vkGetInstanceProcAddr);
    instance = Instance.init(vk_instance, &vki);
    errdefer instance.destroyInstance(null);

}

pub fn createDevice(allocator: Allocator, surface: Surface) !Device {
    const candidate = try pickPhysicalDevice(instance, surface.handle, allocator);
    log.info("chose device '{s}'", .{std.mem.sliceTo(&candidate.props.device_name, 0)});
    return Device.init(instance, candidate, &vkd);
}

pub const Surface = struct {
    handle: vk.SurfaceKHR = .null_handle,

    pub fn deinit(self: *Surface) void {
        log.info("destroying surface", .{});
        instance.destroySurfaceKHR(self.handle, null);
        self.handle = .null_handle;
    }
};

pub fn createSurface(window: *c.SDL_Window) !Surface {
    var ret = Surface{};
    if (!c.SDL_Vulkan_CreateSurface(
        window,
        @ptrFromInt(@intFromEnum(instance.handle)),
        null,
        @ptrCast(&ret.handle)
    )) {
        return error.FailedToCreateSurface;
    }
    return ret;
}

pub fn createSwapchain() !Swapchain {
    return Swapchain.init(instance, );
}

pub fn deinit() void {
    log.info("deinit", .{});

    // TODO: destroy all window surfaces somehow

    log.info("destroying instance", .{});
    instance.destroyInstance(null);
}
