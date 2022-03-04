const std = @import("std");
const vk = @import("vulkan");
const dispatch_types = @import("dispatch_types.zig");
const DeviceDispatch = dispatch_types.DeviceDispatch;
const InstanceDispatch = dispatch_types.InstanceDispatch;

/// the requirements of a device
const Requirements = struct {
    graphics: bool = true,
    present: bool = true,
    compute: bool = true,
    transfer: bool = true,

    extensions: []const [:0]const u8 = &[_][:0]const u8{
        vk.extension_info.khr_swapchain.name,
        //        vk.extension_info.khr_maintenance_1.name,
    },

    /// idk what this is
    sampler_anisotropy: bool = true,
    discrete: bool = true,
};

pub const Queue = struct {
    idx: u32,
    handle: vk.Queue,
};

/// Encapsulates the physical and logical device combination
/// and the properties thereof
pub const Device = struct {
    /// dispatch for functions which use this device
    vkd: DeviceDispatch,

    physical: vk.PhysicalDevice,

    /// properties of a the device
    props: vk.PhysicalDeviceProperties,
    memory: vk.PhysicalDeviceMemoryProperties,
    features: vk.PhysicalDeviceFeatures,

    graphics: ?Queue = null,
    present: ?Queue = null,
    transfer: ?Queue = null,
    compute: ?Queue = null,

    supports_device_local_host_visible: bool,

    logical: vk.Device,

    command_pool: vk.CommandPool,

    depth_format: vk.Format,

    const Self = @This();

    /// Creates a device if a suitable one can be found
    /// if not, returns an error
    pub fn init(
        reqs: Requirements,
        instance: vk.Instance,
        vki: InstanceDispatch,
        surface: vk.SurfaceKHR,
        allocator: std.mem.Allocator,
    ) !Self {
        var self = try selectPhysicalDevice(instance, vki, surface, reqs, allocator);

        // get depth format
        try self.getDepthFormat(vki);

        // gather count of queues that share each index
        var indices = [_]u32{ 0, 0, 0, 0 };

        if (self.graphics) |q| {
            indices[q.idx] += 1;
            std.log.info("graphics idx: {}", .{q.idx});
        }
        if (self.compute) |q| {
            indices[q.idx] += 1;
            std.log.info("compute idx: {}", .{q.idx});
        }
        if (self.transfer) |q| {
            indices[q.idx] += 1;
            std.log.info("transfer idx: {}", .{q.idx});
        }
        if (self.present) |q| {
            indices[q.idx] += 1;
            std.log.info("present idx: {}", .{q.idx});
        }

        const priority = [_]f32{1};
        var qci: [4]vk.DeviceQueueCreateInfo = undefined;
        var last: usize = 0;
        var n_unique: u32 = 0;

        for (indices) |n, idx| {
            if (n > 0) {
                n_unique += 1;
                qci[last] = .{
                    .flags = .{},
                    .queue_family_index = @intCast(u32, idx),
                    .queue_count = @intCast(u32, 1),
                    .p_queue_priorities = &priority,
                };
                last += 1;
            }
        }

        self.logical = try vki.createDevice(self.physical, &.{
            .flags = .{},
            .queue_create_info_count = n_unique,
            //.queue_create_info_count = 1,
            .p_queue_create_infos = &qci,
            // TODO: add features
            .p_enabled_features = &.{
                //.sampler_anisotropy = vk.TRUE,
            },
            .enabled_extension_count = @intCast(u32, reqs.extensions.len),
            //.enabled_extension_count = 1,
            .pp_enabled_extension_names = @ptrCast([*]const [*:0]const u8, reqs.extensions),
            .enabled_layer_count = 0,
            .pp_enabled_layer_names = undefined,
        }, null);

        // setup the device dispatch
        self.vkd = try DeviceDispatch.load(self.logical, vki.dispatch.vkGetDeviceProcAddr);

        // setup the queues
        if (self.graphics) |*q| {
            q.handle = self.vkd.getDeviceQueue(self.logical, q.idx, 0);
        }
        if (self.compute) |*q| {
            q.handle = self.vkd.getDeviceQueue(self.logical, q.idx, 0);
        }
        if (self.transfer) |*q| {
            q.handle = self.vkd.getDeviceQueue(self.logical, q.idx, 0);
        }
        if (self.present) |*q| {
            q.handle = self.vkd.getDeviceQueue(self.logical, q.idx, 0);
        }

        // create the command pool
        self.command_pool = try self.vkd.createCommandPool(self.logical, &.{
            .flags = .{ .reset_command_buffer_bit = true },
            .queue_family_index = self.graphics.?.idx,
        }, null);

        return self;
    }

    /// destroys the device and associated memory
    pub fn deinit(self: Self) void {
        self.vkd.destroyCommandPool(self.logical, self.command_pool, null);
        self.vkd.destroyDevice(self.logical, null);
    }

    /// finds a physical device based on the requirements given
    fn selectPhysicalDevice(
        instance: vk.Instance,
        vki: InstanceDispatch,
        surface: vk.SurfaceKHR,
        reqs: Requirements,
        allocator: std.mem.Allocator,
    ) !Self {
        var ret: Self = undefined;
        // loop over devices first and look for suitable one
        var device_count: u32 = undefined;
        _ = try vki.enumeratePhysicalDevices(instance, &device_count, null);

        const pdevs = try allocator.alloc(vk.PhysicalDevice, device_count);
        defer allocator.free(pdevs);

        _ = try vki.enumeratePhysicalDevices(instance, &device_count, pdevs.ptr);

        for (pdevs) |pdev| {

            // get properties
            const props = vki.getPhysicalDeviceProperties(pdev);
            const mem = vki.getPhysicalDeviceMemoryProperties(pdev);
            const features = vki.getPhysicalDeviceFeatures(pdev);

            std.log.info("looking at device: {s}", .{props.device_name});

            if (reqs.discrete and !(props.device_type == vk.PhysicalDeviceType.discrete_gpu)) {
                std.log.warn("device {s} does not meet requirement of discrete gpu", .{props.device_name});
                continue;
            }

            // TODO: check if it supports host visible
            // check extension support
            const has_required_ext = blk: {
                var count: u32 = undefined;
                _ = try vki.enumerateDeviceExtensionProperties(pdev, null, &count, null);

                const extv = try allocator.alloc(vk.ExtensionProperties, count);
                defer allocator.free(extv);

                _ = try vki.enumerateDeviceExtensionProperties(pdev, null, &count, extv.ptr);

                // TODO: use provided list from requirements
                for (reqs.extensions) |ext| {
                    for (extv) |e| {
                        const len = std.mem.indexOfScalar(u8, &e.extension_name, 0).?;
                        const prop_ext_name = e.extension_name[0..len];
                        if (std.mem.eql(u8, ext[0..], prop_ext_name)) {
                            break;
                        }
                    } else {
                        std.log.warn("device {s} does not have required extension {s}", .{ props.device_name, ext });
                        break :blk false;
                    }
                }

                // we have all the ext
                break :blk true;
            };

            if (!has_required_ext)
                continue;

            // get queue families
            {
                var count: u32 = 0;
                vki.getPhysicalDeviceQueueFamilyProperties(pdev, &count, null);

                const qpropv = try allocator.alloc(vk.QueueFamilyProperties, count);
                defer allocator.free(qpropv);

                vki.getPhysicalDeviceQueueFamilyProperties(pdev, &count, qpropv.ptr);

                var min_transfer_score: u8 = 255;

                for (qpropv) |qprop, idx| {
                    var cur_transfer_score: u8 = 0;
                    const i = @intCast(u32, idx);

                    if ((ret.graphics == null) and qprop.queue_flags.graphics_bit) {
                        ret.graphics = .{ .idx = i, .handle = undefined };
                        cur_transfer_score += 1;
                    }

                    // check if this device supports surfaces
                    if ((ret.present == null) and (try vki.getPhysicalDeviceSurfaceSupportKHR(pdev, i, surface)) == vk.TRUE) {
                        ret.present = .{ .idx = i, .handle = undefined };
                        cur_transfer_score += 1;
                    }

                    if ((ret.compute == null) and qprop.queue_flags.compute_bit) {
                        if (ret.graphics.?.idx == i) continue;
                        if (ret.present.?.idx == i) continue;
                        ret.compute = .{ .idx = i, .handle = undefined };
                        cur_transfer_score += 1;
                    }

                    // doing this so that transfer has its own
                    if (qprop.queue_flags.transfer_bit) {
                        if (cur_transfer_score <= min_transfer_score) {
                            min_transfer_score = cur_transfer_score;
                            ret.transfer = .{ .idx = i, .handle = undefined };
                        }
                    }
                }
            }

            if (ret.graphics == null and reqs.graphics) {
                std.log.warn("device {s} does not meet requirement of graphics queue", .{props.device_name});
                continue;
            }
            if (ret.present == null and reqs.present) {
                std.log.warn("device {s} does not meet requirement of present queue", .{props.device_name});
                continue;
            }
            if (ret.compute == null and reqs.compute) {
                std.log.warn("device {s} does not meet requirement of compute queue", .{props.device_name});
                continue;
            }
            if (ret.transfer == null and reqs.transfer) {
                std.log.warn("device {s} does not meet requirement of transfer queue", .{props.device_name});
                continue;
            }

            // check for swapchain support
            var format_count: u32 = undefined;
            _ = try vki.getPhysicalDeviceSurfaceFormatsKHR(pdev, surface, &format_count, null);

            var present_mode_count: u32 = undefined;
            _ = try vki.getPhysicalDeviceSurfacePresentModesKHR(pdev, surface, &present_mode_count, null);

            if (format_count == 0) {
                std.log.warn("device {s} does not meet requirement of surface formats", .{props.device_name});
                continue;
            }

            if (present_mode_count == 0) {
                std.log.warn("device {s} does not meet requirement of surface present modes", .{props.device_name});
                continue;
            }

            ret.props = props;
            ret.memory = mem;
            ret.features = features;
            ret.physical = pdev;

            std.log.info("device {s} meets requirements", .{props.device_name});
            return ret;
        }

        return error.NoSuitableDevice;
    }

    pub fn findMemoryIndex(self: Self, type_bits: u32, flags: vk.MemoryPropertyFlags) !u32 {
        for (self.memory.memory_types[0..self.memory.memory_type_count]) |mem_type, i| {
            if (type_bits & (@as(u32, 1) << @truncate(u5, i)) != 0 and mem_type.property_flags.contains(flags)) {
                return @truncate(u32, i);
            }
        }

        std.log.err("cannot find mem index type: {} flags: {}", .{ type_bits, flags });

        return error.CannotFindMemoryIndex;
    }

    fn getDepthFormat(self: *Self, vki: InstanceDispatch) !void {
        const candidates = [_]vk.Format{ .d32_sfloat, .d32_sfloat_s8_uint, .d24_unorm_s8_uint };

        for (candidates) |fmt| {
            const props = vki.getPhysicalDeviceFormatProperties(self.physical, fmt);

            if (props.linear_tiling_features.depth_stencil_attachment_bit) {
                self.depth_format = fmt;
                return;
            }
            if (props.optimal_tiling_features.depth_stencil_attachment_bit) {
                self.depth_format = fmt;
                return;
            }
        }

        return error.CannotFindDepthFormat;
    }
};
