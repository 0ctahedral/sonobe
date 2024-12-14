const std = @import("std");
const core = @import("../core/core.zig");
const log = core.logger.Logger("gpu");
const Window = @import("platform.zig").Window;

const Allocator = std.mem.Allocator;

// const Window = @import("window.zig").Window;

const vk = @import("vulkan");
const c = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_vulkan.h");
});

const apis: []const vk.ApiInfo = &.{
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

// TODO: configurable?
const required_device_extensions = [_][*:0]const u8{vk.extensions.khr_swapchain.name};

const BaseDispatch = vk.BaseWrapper(apis);
const InstanceDispatch = vk.InstanceWrapper(apis);
const Instance = vk.InstanceProxy(apis);

const DeviceDispatch = vk.DeviceWrapper(apis);
const Device = vk.DeviceProxy(apis);

const Self = @This();
pub var vki: InstanceDispatch = undefined;
pub var instance: Instance = undefined;

pub var vkd: DeviceDispatch = undefined;
pub var device: Device = undefined;

pub fn init(window: *Window, allocator: Allocator) !void {
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
        log.debug("extension {}: {s}", .{i, value});
    }

    const app_info = vk.ApplicationInfo{
        .p_application_name = window.getTitle(),
        .application_version = vk.makeApiVersion(0, 0, 0, 0),
        .p_engine_name = window.getTitle(),
        .engine_version = vk.makeApiVersion(0, 0, 0, 0),
        .api_version = vk.API_VERSION_1_2,
    };

    const layers = &[_][*:0]const u8{
        // vk.extensions.khr_portability_enumeration.name
        // vk.extensions.ext_validation_features.name,
    };

    const vk_instance = try vkb.createInstance(&.{
        .p_application_info = &app_info,
        .enabled_extension_count = required_exts.len,
        .pp_enabled_extension_names = @ptrCast(required_exts),
        .enabled_layer_count = layers.len,
        .pp_enabled_layer_names = @ptrCast(layers),
        .flags = .{.enumerate_portability_bit_khr = true}
    }, null);

    vki = try InstanceDispatch.load(vk_instance, vkb.dispatch.vkGetInstanceProcAddr);
    instance = Instance.init(vk_instance, &vki);
    errdefer instance.destroyInstance(null);

    const surface = try window.getSurface();

    const candidate = try pickPhysicalDevice(allocator, surface);
    log.info("chose device '{s}', initializing", .{std.mem.sliceTo(&candidate.props.device_name, 0)});

    const dev = try initializeCandidate(candidate);
    vkd = try DeviceDispatch.load(dev, instance.wrapper.dispatch.vkGetDeviceProcAddr);
    device = Device.init(dev, &vkd);
    errdefer device.destroyDevice(null);

}

pub fn deinit() void {
    log.info("deinit", .{});
    
    // TODO: destroy all window surfaces somehow

    log.info("destroying device", .{});
    device.destroyDevice(null);
    log.info("destroying instance", .{});
    instance.destroyInstance(null);
}

const QueueAllocation = struct {
    graphics_family: u32,
    present_family: u32,
};

const DeviceCandidate = struct {
    pdev: vk.PhysicalDevice,
    props: vk.PhysicalDeviceProperties,
    queues: QueueAllocation,
};

fn initializeCandidate(candidate: DeviceCandidate) !vk.Device {
    const priority = [_]f32{1};
    const qci = [_]vk.DeviceQueueCreateInfo{
        .{
            .queue_family_index = candidate.queues.graphics_family,
            .queue_count = 1,
            .p_queue_priorities = &priority,
        },
        .{
            .queue_family_index = candidate.queues.present_family,
            .queue_count = 1,
            .p_queue_priorities = &priority,
        },
    };

    const queue_count: u32 = if (candidate.queues.graphics_family == candidate.queues.present_family)
        1
    else
        2;

    return try instance.createDevice(candidate.pdev, &.{
        .queue_create_info_count = queue_count,
        .p_queue_create_infos = &qci,
        .enabled_extension_count = required_device_extensions.len,
        .pp_enabled_extension_names = @ptrCast(&required_device_extensions),
    }, null);
}

// TODO: this should also initialize the device
// TODO: move to a struct of some sort
fn pickPhysicalDevice(
    allocator: Allocator,
    surface: vk.SurfaceKHR
) !DeviceCandidate {
    const pdevs = try instance.enumeratePhysicalDevicesAlloc(allocator);
    defer allocator.free(pdevs);

    // TODO: this selects the first suitable device, might want to instead
    // get the "best" device
    for (pdevs) |pdev| {
        if (try checkSuitable(pdev, allocator, surface)) |candidate| {
            return candidate;
        }
    }

    return error.NoSuitableDevice;
}

fn checkSuitable(
    pdev: vk.PhysicalDevice,
    allocator: Allocator,
    surface: vk.SurfaceKHR,
) !?DeviceCandidate {
    const props = instance.getPhysicalDeviceProperties(pdev);
    log.debug("checking if device '{s}' ({}) is suitable", .{std.mem.sliceTo(&props.device_name, 0), pdev});

    if (!try checkExtensionSupport(pdev, allocator)) {
        return null;
    }

    if (!try checkSurfaceSupport(pdev, surface)) {
        return null;
    }

    if (try allocateQueues(pdev, allocator, surface)) |allocation| {
        return DeviceCandidate{
            .pdev = pdev,
            .props = props,
            .queues = allocation,
        };
    }

    return null;
}

fn allocateQueues(
    pdev: vk.PhysicalDevice,
    allocator: Allocator,
    surface: vk.SurfaceKHR
) !?QueueAllocation {
    const families = try instance.getPhysicalDeviceQueueFamilyPropertiesAlloc(pdev, allocator);
    defer allocator.free(families);

    var graphics_family: ?u32 = null;
    var present_family: ?u32 = null;


    log.debug("device {}: found {} queue families", .{pdev, families.len});

    for (families, 0..) |properties, i| {
        const family: u32 = @intCast(i);

        if (graphics_family == null and properties.queue_flags.graphics_bit) {
            graphics_family = family;
        }

        if (present_family == null and (try instance.getPhysicalDeviceSurfaceSupportKHR(pdev, family, surface)) == vk.TRUE) {
            present_family = family;
        }
    }


    if (graphics_family == null) {
        log.warn("device {}: could not find graphics queue family", .{pdev});
        return null;
    }

    if (present_family == null) {
        log.warn("device {}: could not find present queue family", .{pdev});
        return null;
    }

    log.debug("device {}: graphics queue idx: {} present queue idx: {}", .{pdev, graphics_family.?, present_family.?});

    return QueueAllocation{
        .graphics_family = graphics_family.?,
        .present_family = present_family.?,
    };

}

fn checkSurfaceSupport(
    pdev: vk.PhysicalDevice,
    surface: vk.SurfaceKHR
) !bool {
    var format_count: u32 = undefined;
    _ = try instance.getPhysicalDeviceSurfaceFormatsKHR(pdev, surface, &format_count, null);
    if (format_count == 0) {
        log.warn("device {}: does not have any surface formats", .{pdev});
        return false;
    }

    var present_mode_count: u32 = undefined;
    _ = try instance.getPhysicalDeviceSurfacePresentModesKHR(pdev, surface, &present_mode_count, null);
    if (present_mode_count == 0) {
        log.warn("device {} does not have any present modes", .{pdev});
        return false;
    }
    log.debug("device {}: {} surface formats and {} present modes", .{pdev, format_count, present_mode_count});

    return true;
}

fn checkExtensionSupport(
    pdev: vk.PhysicalDevice,
    allocator: Allocator,
) !bool {
    const propsv = try instance.enumerateDeviceExtensionPropertiesAlloc(pdev, null, allocator);
    defer allocator.free(propsv);

    for (required_device_extensions) |ext| {
        log.debug("device {}: checking for extension {s}", .{pdev, ext});
        for (propsv) |props| {
            if (std.mem.eql(u8, std.mem.span(ext), std.mem.sliceTo(&props.extension_name, 0))) {
                break;
            }
        } else {
            log.warn("device {}: does not have extension {s}", .{pdev, ext});
            return false;
        }
    }

    return true;
}
