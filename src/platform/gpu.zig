const vk = @import("vulkan");
const core = @import("../core/core.zig");
pub const log = core.logger.Logger("gpu");
const c = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_vulkan.h");
});

const app_name = "foobar";
const apis: []const vk.ApiInfo = &.{
    // You can either add invidiual functions by manually creating an 'api'
    .{
        .base_commands = .{
            .createInstance = true,
        },
        .instance_commands = .{
            .createDevice = true,
        },
    },
    // Or you can add entire feature sets or extensions
    vk.features.version_1_0,
    vk.extensions.khr_surface,
    vk.extensions.khr_swapchain,
};

const BaseDispatch = vk.BaseWrapper(apis);
const InstanceDispatch = vk.InstanceWrapper(apis);
const Instance = vk.InstanceProxy(apis);

const Self = @This();
pub var vki: InstanceDispatch = undefined;
pub var instance: Instance = undefined;

    // const DeviceDispatch = vk.DeviceWrapper(apis);

// pub fn init() !Self {
pub fn init() !void {

    // TODO: move to graphics
    if (!c.SDL_Vulkan_LoadLibrary(null)) {
        return error.CouldNotLoadVulkan;
    }


    // const Device = vk.DeviceProxy(apis);
    const proc_addr: *const fn (instance: vk.Instance, procname: [*:0]const u8) vk.PfnVoidFunction = @ptrCast(c.SDL_Vulkan_GetVkGetInstanceProcAddr());
    var vkb: BaseDispatch = try BaseDispatch.load(proc_addr);

    const required_exts: []const [*:0]const u8 = &[_][*:0]const u8{
        vk.extensions.khr_surface.name,
        vk.extensions.ext_metal_surface.name,
        vk.extensions.khr_portability_enumeration.name,
    };

    log.info("loading extensions:", .{});
    for (required_exts, 0..) |value, i| {
        log.info("extension {}: {s}", .{i, value});
    }

    const app_info = vk.ApplicationInfo{
        .p_application_name = app_name,
        .application_version = vk.makeApiVersion(0, 0, 0, 0),
        .p_engine_name = app_name,
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

    // return .{
    //     .vki = vki,
    //     .instance = instance,
    // };
}
