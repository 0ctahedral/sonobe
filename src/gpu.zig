const std = @import("std");
const core = @import("core.zig");
pub const log = core.logger.Logger("gpu");

pub const pipeline = @import("gpu/pipeline.zig");
const dev = @import("gpu/device.zig");
const Device = dev.Device;
const pickPhysicalDevice = dev.pickPhysicalDevice;

const Window = @import("platform.zig").Window;

const Swapchain = @import("gpu/Swapchain.zig");

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
const DeviceDispatch = vk.DeviceWrapper(apis);
pub const Instance = vk.InstanceProxy(apis);

const Self = @This();

pub var vki: InstanceDispatch = undefined;
pub var instance: Instance = undefined;
var vkd: DeviceDispatch = undefined;

var alloc: Allocator = undefined;

pub fn init(allocator: Allocator) !void {
    log.info("init", .{});

    alloc = allocator;

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

pub fn createDevice(surface: Surface) !*Device {
    const candidate = try pickPhysicalDevice(instance, surface.handle, alloc);
    log.info("chose device '{s}'", .{std.mem.sliceTo(&candidate.props.device_name, 0)});
    return Device.init(instance, candidate, &vkd, alloc);
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

pub fn createSwapchain(device: *const Device, window: Window) !Swapchain {
    return Swapchain.init(instance, device, window.surface.?.handle, window.w, window.h, alloc);
}

pub fn createRenderPass(device: *const Device, swapchain: *const Swapchain) !vk.RenderPass {
    const color_attachment = vk.AttachmentDescription{
        .format = swapchain.surface_format.format,
        .samples = .{ .@"1_bit" = true },
        .load_op = .clear,
        .store_op = .store,
        .stencil_load_op = .dont_care,
        .stencil_store_op = .dont_care,
        .initial_layout = .undefined,
        .final_layout = .present_src_khr,
    };

    const color_attachment_ref = vk.AttachmentReference{
        .attachment = 0,
        .layout = .color_attachment_optimal,
    };

    const subpass = vk.SubpassDescription{
        .pipeline_bind_point = .graphics,
        .color_attachment_count = 1,
        .p_color_attachments = @ptrCast(&color_attachment_ref),
    };

    return try device.dev.createRenderPass(&.{
        .attachment_count = 1,
        .p_attachments = @ptrCast(&color_attachment),
        .subpass_count = 1,
        .p_subpasses = @ptrCast(&subpass),
    }, null);

}

const Vertex = struct {
    pos: [2]f32,
    color: [3]f32,
};

const vertices = [_]Vertex{
    .{ .pos = .{ 0, -0.5 }, .color = .{ 1, 0, 0 } },
    .{ .pos = .{ 0.5, 0.5 }, .color = .{ 0, 1, 0 } },
    .{ .pos = .{ -0.5, 0.5 }, .color = .{ 0, 0, 1 } },
};

pub fn createPipeline(device: *const Device, desc: pipeline.PipelineDesc, render_pass: vk.RenderPass) !pipeline.Pipeline {
    const layouts = [_]vk.DescriptorSetLayout{
    };
    const vertex_inputs = [_]vk.VertexInputBindingDescription{
        .{
            .binding = 0,
            .stride = @sizeOf(Vertex),
            .input_rate = .vertex,
        },
    };
    const vertex_attrs = [_]vk.VertexInputAttributeDescription{
        .{
            .binding = 0,
            .location = 0,
            .format = .r32g32_sfloat,
            .offset = @offsetOf(Vertex, "pos"),
        },
        .{
            .binding = 0,
            .location = 1,
            .format = .r32g32b32_sfloat,
            .offset = @offsetOf(Vertex, "color"),
        },
    };

    return try pipeline.Pipeline.init(
        device,        
        desc,
        render_pass,
        &layouts,
        &.{},
        false,
        &vertex_inputs,
        &vertex_attrs,
        alloc,
    );
}

pub fn createFrameBuffers(
    device: *const Device,
    swapchain: *const Swapchain,
    render_pass: vk.RenderPass,
) ![]vk.Framebuffer {
    log.info("creating {} framebuffers", .{swapchain.swap_imgs.len});
    const framebuffers = try alloc.alloc(vk.Framebuffer, swapchain.swap_imgs.len);
    errdefer alloc.free(framebuffers);

    var i: usize = 0;
    errdefer for (framebuffers[0..i]) |fb| device.dev.destroyFramebuffer(fb, null);

    for (framebuffers) |*fb| {
        fb.* = try device.dev.createFramebuffer(&.{
            .render_pass = render_pass,
            .attachment_count = 1,
            .p_attachments = @ptrCast(&swapchain.swap_imgs[i].view),
            .width = swapchain.extent.width,
            .height = swapchain.extent.height,
            .layers = 1,
        }, null);
        i += 1;
    }

    return framebuffers;
}

pub fn destroyFrameBuffers(device: *const Device, framebuffers: []vk.Framebuffer) void {
    log.info("destroying {} framebuffers", .{framebuffers.len});
    for (framebuffers) |fb| device.dev.destroyFramebuffer(fb, null);
    alloc.free(framebuffers);
}

pub fn deinit() void {
    log.info("deinit", .{});

    // TODO: destroy all window surfaces somehow

    log.info("destroying instance", .{});
    instance.destroyInstance(null);
}
