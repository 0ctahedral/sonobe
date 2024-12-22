const std = @import("std");
const vk = @import("vulkan");
const gpu = @import("../gpu.zig");

const log = gpu.log.sub("device");

const Allocator = std.mem.Allocator;

const DeviceDispatch = vk.DeviceWrapper(gpu.apis);
const VkDevice = vk.DeviceProxy(gpu.apis);

const required_device_extensions = [_][*:0]const u8{vk.extensions.khr_swapchain.name};

pub const Queue = struct {
    handle: vk.Queue,
    family: u32,
};

pub const Device = struct {
    // TODO: who should own physical vs logical device
    dev: VkDevice,
    pdev: vk.PhysicalDevice,

    graphics: ?Queue = null,
    present: ?Queue = null,
    transfer: ?Queue = null,
    compute: ?Queue = null,

    /// properties of a the device
    props: vk.PhysicalDeviceProperties,
    mem_props: vk.PhysicalDeviceMemoryProperties,
    features: vk.PhysicalDeviceFeatures,

    alloc: Allocator,

    pub fn init(instance: gpu.Instance, candidate: DeviceCandidate, vkd: *DeviceDispatch, allocator: Allocator) !*Device {
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

        log.info("creating device '{s}'", .{std.mem.sliceTo(&candidate.props.device_name, 0)});
        const handle = try instance.createDevice(
            candidate.pdev,
            &.{
                .queue_create_info_count = queue_count,
                .p_queue_create_infos = &qci,
                .enabled_extension_count = required_device_extensions.len,
                .pp_enabled_extension_names = @ptrCast(&required_device_extensions),
            },
            null,
        );

        const pdev = candidate.pdev;

        vkd.* = try DeviceDispatch.load(handle, instance.wrapper.dispatch.vkGetDeviceProcAddr);

        const device = try allocator.create(Device);

        device.* = .{
            .dev = VkDevice.init(handle, vkd),
            .pdev = pdev,
            .props = instance.getPhysicalDeviceProperties(pdev),
            .mem_props = instance.getPhysicalDeviceMemoryProperties(pdev),
            .features = instance.getPhysicalDeviceFeatures(pdev),
            .alloc = allocator,
        };

        device.graphics = .{
            .handle = device.dev.getDeviceQueue(candidate.queues.graphics_family, 0),
            .family = candidate.queues.graphics_family,
        };
        device.present = .{
            .handle = device.dev.getDeviceQueue(candidate.queues.present_family, 0),
            .family = candidate.queues.present_family,
        };

        return device;
    }

    pub fn deinit(self: *Device) void {
        log.info("destroying device {s}", .{self.props.device_name});
        self.dev.destroyDevice(null);
        self.alloc.destroy(self);
    }

    pub fn allocate(self: Device, requirements: vk.MemoryRequirements, flags: vk.MemoryPropertyFlags) !vk.DeviceMemory {
        return try self.dev.allocateMemory(&.{
            .allocation_size = requirements.size,
            .memory_type_index = try self.findMemoryIndex(requirements.memory_type_bits, flags),
        }, null);
    }

    pub fn findMemoryIndex(self: Device, type_bits: u32, flags: vk.MemoryPropertyFlags) !u32 {
        for (self.mem_props.memory_types[0..self.mem_props.memory_type_count], 0..) |mem_type, i| {
            if (type_bits & (@as(u32, 1) << @truncate(i)) != 0 and mem_type.property_flags.contains(flags)) {
                return @truncate(i);
            }
        }

        log.err("cannot find mem index type: {} flags: {}", .{ type_bits, flags });

        return error.CannotFindMemoryIndex;
    }

    pub fn submit(self: Device, cmdbuf: vk.CommandBuffer) !void {
        const si = vk.SubmitInfo{
            .command_buffer_count = 1,
            .p_command_buffers = (&cmdbuf)[0..1],
            .p_wait_dst_stage_mask = undefined,
        };
        // TODO: no fence needed because we are waiting idle here?
        try self.dev.queueSubmit(self.graphics.?.handle, 1, @ptrCast(&si), .null_handle);
        try self.dev.queueWaitIdle(self.graphics.?.handle);
    }
};

const QueueAllocation = struct {
    graphics_family: u32,
    present_family: u32,
};

const DeviceCandidate = struct {
    pdev: vk.PhysicalDevice,
    props: vk.PhysicalDeviceProperties,
    queues: QueueAllocation,
};

pub fn pickPhysicalDevice(
    instance: gpu.Instance,
    surface: vk.SurfaceKHR,
    allocator: Allocator,
) !DeviceCandidate {
    const pdevs = try instance.enumeratePhysicalDevicesAlloc(allocator);
    defer allocator.free(pdevs);

    // TODO: this selects the first suitable device, might want to instead
    // get the "best" device or give a list of devices
    for (pdevs) |pdev| {
        if (try checkSuitable(instance, pdev, surface, allocator)) |candidate| {
            return candidate;
        }
    }

    return error.NoSuitableDevice;
}

fn checkSuitable(
    instance: gpu.Instance,
    pdev: vk.PhysicalDevice,
    surface: vk.SurfaceKHR,
    allocator: Allocator,
) !?DeviceCandidate {
    const props = instance.getPhysicalDeviceProperties(pdev);
    log.debug("checking if device '{s}' ({}) is suitable", .{ std.mem.sliceTo(&props.device_name, 0), pdev });

    if (!try checkExtensionSupport(instance, pdev, allocator)) {
        return null;
    }

    if (!try checkSurfaceSupport(instance, pdev, surface)) {
        return null;
    }

    if (try allocateQueues(instance, pdev, surface, allocator)) |allocation| {
        return DeviceCandidate{
            .pdev = pdev,
            .props = props,
            .queues = allocation,
        };
    }

    return null;
}

fn allocateQueues(
    instance: gpu.Instance,
    pdev: vk.PhysicalDevice,
    surface: vk.SurfaceKHR,
    allocator: Allocator,
) !?QueueAllocation {
    const families = try instance.getPhysicalDeviceQueueFamilyPropertiesAlloc(pdev, allocator);
    defer allocator.free(families);

    var graphics_family: ?u32 = null;
    var present_family: ?u32 = null;

    log.debug("device {}: found {} queue families", .{ pdev, families.len });

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

    log.debug("device {}: graphics queue idx: {} present queue idx: {}", .{ pdev, graphics_family.?, present_family.? });

    return QueueAllocation{
        .graphics_family = graphics_family.?,
        .present_family = present_family.?,
    };
}

fn checkSurfaceSupport(
    instance: gpu.Instance,
    pdev: vk.PhysicalDevice,
    surface: vk.SurfaceKHR,
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
    log.debug("device {}: {} surface formats and {} present modes", .{ pdev, format_count, present_mode_count });

    return true;
}

fn checkExtensionSupport(
    instance: gpu.Instance,
    pdev: vk.PhysicalDevice,
    allocator: Allocator,
) !bool {
    const propsv = try instance.enumerateDeviceExtensionPropertiesAlloc(pdev, null, allocator);
    defer allocator.free(propsv);

    for (required_device_extensions) |ext| {
        log.debug("device {}: checking for extension {s}", .{ pdev, ext });
        for (propsv) |props| {
            if (std.mem.eql(u8, std.mem.span(ext), std.mem.sliceTo(&props.extension_name, 0))) {
                break;
            }
        } else {
            log.warn("device {}: does not have extension {s}", .{ pdev, ext });
            return false;
        }
    }

    return true;
}
