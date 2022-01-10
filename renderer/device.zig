const std = @import("std");
const vk = @import("vulkan");
const render_types = @import("render_types.zig");

const default_ext = [_][:0]const u8{
    vk.extension_info.khr_swapchain.name,
};

// TODO: this will be set somewhere else
const Requirements = struct {
    graphics: bool = true,
    present: bool = true,
    compute: bool = true,
    transfer: bool = true,

    // TODO: make this work?
    //extensions: [][*:0]const u8 = &default_ext[0..2],

    /// idk what this is
    sampler_anisotropy: bool = true,
    descrete: bool = false,
};
/// Encapsulates the physical and logical device combination
/// and the properties thereof
pub const Device = struct {
    physical: vk.PhysicalDevice,

    /// properties of a the device
    props: vk.PhysicalDeviceProperties,
    memory: vk.PhysicalDeviceMemoryProperties,
    features: vk.PhysicalDeviceFeatures,

    /// indices of the queues
    graphics_idx: i32,
    present_idx: i32,
    compute_idx: i3,
    transfer_idx: i32,

    supports_device_local_host_visible: bool,

    // logical
    logical: vk.Device,
    graphics_queue: vk.Queue,
    present_queue: vk.Queue,
    transfer_queue: vk.Queue,
    compute_queue: vk.Queue,

    const Self = @This();

    /// Creates a device if a suitable one can be found
    /// if not, returns an error
    pub fn init(
        instance: vk.Instance,
        vki: render_types.InstanceDispatch,
        surface: vk.SurfaceKHR,
        allocator: std.mem.Allocator,
    ) !Self {
        var ret = try selectPhysicalDevice(instance, vki, surface, allocator);
        _ = ret;
        return error.NotImplemented;
    }

    /// sets up the physical part of the device
    fn selectPhysicalDevice(
        instance: vk.Instance,
        vki: render_types.InstanceDispatch,
        surface: vk.SurfaceKHR,
        allocator: std.mem.Allocator,
    ) !Self {
        _ = surface;
        var ret: Self = undefined;
        // loop over devices first and look for suitable one
        var device_count: u32 = undefined;
        _ = try vki.enumeratePhysicalDevices(instance, &device_count, null);

        const pdevs = try allocator.alloc(vk.PhysicalDevice, device_count);
        defer allocator.free(pdevs);

        _ = try vki.enumeratePhysicalDevices(instance, &device_count, pdevs.ptr);

        //const reqs = Requirements{};

        for (pdevs) |pdev| {
            // get properties
            const props = vki.getPhysicalDeviceProperties(pdev);
            const mem = vki.getPhysicalDeviceMemoryProperties(pdev);
            const features = vki.getPhysicalDeviceFeatures(pdev);

            std.log.info("looking at device: {s}", .{props.device_name});

            var meets_requirements = false;

            // TODO: check if it supports host visible
            // check extension support
            const has_required_ext = blk: {
                var count: u32 = undefined;
                _ = try vki.enumerateDeviceExtensionProperties(pdev, null, &count, null);

                const extv = try allocator.alloc(vk.ExtensionProperties, count);
                defer allocator.free(extv);

                _ = try vki.enumerateDeviceExtensionProperties(pdev, null, &count, extv.ptr);

                for (default_ext) |ext| {
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

            if (!has_required_ext) {
                continue;
            }

            // check surface support
            // queue families

            if (meets_requirements) {
                ret.props = props;
                ret.memory = mem;
                ret.features = features;

                std.log.info("device {s} meets requirements", .{props.device_name});
                return ret;
            }
        }

        return error.NoSuitableDevice;
    }

    /// destroys the device and associated memory
    pub fn deinit(self: Self) void {
        _ = self;
    }
};
