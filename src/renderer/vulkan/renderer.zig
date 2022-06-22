const std = @import("std");
const vk = @import("vulkan");

// TODO: get rid of this dependency if possible
const Platform = @import("../../platform.zig");

const types = @import("../rendertypes.zig");
const Handle = types.Handle;
const CmdBuf = @import("../cmdbuf.zig");

const dispatch_types = @import("dispatch_types.zig");
const BaseDispatch = dispatch_types.BaseDispatch;
const InstanceDispatch = dispatch_types.InstanceDispatch;
const Allocator = std.mem.Allocator;

const Device = @import("device.zig").Device;
const Queue = @import("device.zig").Queue;
const Swapchain = @import("swapchain.zig").Swapchain;
const RenderPass = @import("renderpass.zig").RenderPass;
const CommandBuffer = @import("commandbuffer.zig").CommandBuffer;
const Fence = @import("fence.zig").Fence;
const Semaphore = @import("semaphore.zig").Semaphore;
const Pipeline = @import("pipeline.zig").Pipeline;
const Mesh = @import("mesh.zig").Mesh;
const Buffer = @import("buffer.zig").Buffer;
const TextureMap = @import("texture.zig").TextureMap;
const Texture = @import("texture.zig").Texture;
const RenderTarget = @import("render_target.zig").RenderTarget;
pub const Resources = @import("resources.zig");
const mmath = @import("../../math.zig");
const Mat4 = mmath.Mat4;
const Vec3 = mmath.Vec3;
const Vec4 = mmath.Vec4;
const Vec2 = mmath.Vec2;

// TODO: set this in a config
const required_layers = [_][*:0]const u8{"VK_LAYER_KHRONOS_validation"};

var vkb: BaseDispatch = undefined;
var vki: InstanceDispatch = undefined;
var instance: vk.Instance = undefined;
var surface: vk.SurfaceKHR = undefined;
var messenger: vk.DebugUtilsMessengerEXT = undefined;
var device: Device = undefined;
var swapchain: Swapchain = undefined;

/// monotonically increasing frame number
var frame_number: usize = 0;

/// index of the image in the swapchain we are currently
/// rendering to
/// TODO: do we still need this?
var image_index: usize = 0;

/// Allocator used by the renderer
var allocator: Allocator = undefined;

// TODO: these will eventually not exist

var default_renderpass: RenderPass = undefined;

/// pipeline currently being used
var pipeline: Pipeline = undefined;

/// current dimesnsions of the framebuffer
var fb_width: u32 = 0;
var fb_height: u32 = 0;

/// swapchain render targets
var swapchain_render_targets: []RenderTarget = undefined;

const MAX_FRAMES = 2;
/// The currently rendering frames
var frames: [MAX_FRAMES]FrameData = undefined;

// -------------------------------

/// Are we currently recreating the swapchain
/// I don't think this is really used yet but might
/// be useful when we multi thread
var recreating_swapchain = false;

// TODO: might not need
/// generation of this resize
var size_gen: usize = 0;
var last_size_gen: usize = 0;

// these will be part of the shader system

/// descriptor set layout for global data (i.e. camera transform)
var global_descriptor_layout: vk.DescriptorSetLayout = .null_handle;
/// pool from which we allocate all descriptor sets
var global_descriptor_pool: vk.DescriptorPool = .null_handle;
/// descriptor set for the main shader
var global_descriptor_sets: [MAX_FRAMES]vk.DescriptorSet = undefined;

// --------------------------------------

// TODO: this should be from a resource system
var default_texture_map: TextureMap = undefined;
var default_texture: Handle = undefined;

const MeshPushConstants = struct {
    id: u32 align(16) = 0,
    model: Mat4 align(16) = Mat4.identity(),
};

pub var push_constant = MeshPushConstants{};

/// Data to be used for each frame
const GlobalData = struct {
    projection: Mat4 align(16) = Mat4.perspective(mmath.util.rad(70), 800.0 / 600.0, 0.1, 1000),
    // projection: Mat4 = Mat4.ortho(0, 800.0, 0, 600.0, -100, 100),
    view: Mat4 align(16) = Mat4.translate(.{ .x = 0, .y = 0, .z = 10 }).inv(),
};

/// Data to be used per material
const MaterialData = struct {
    albedo: Vec3 align(16),
};

/// buffer for global shader data (rn just the camera matricies)
var global_buffer: Buffer = undefined;
/// shader
var material_buffer: Buffer = undefined;
/// camera matricies
var cam_data = GlobalData{};
/// buffer for the model matricies of objects
var storage_buffer: Buffer = undefined;

// functions that are part of the api

// initialize the renderer
// TODO: should this take in a surface instead of a window?
pub fn init(provided_allocator: Allocator, app_name: [*:0]const u8, window: Platform.Window) !void {
    allocator = provided_allocator;
    // open vulkan dynlib
    // TODO: make local or whatever
    var vk_proc = Platform.getInstanceProcAddress();

    // get proc address from glfw window
    // load the base dispatch functions
    vkb = try BaseDispatch.load(vk_proc);

    fb_width = 800;
    fb_height = 600;

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
        .enabled_layer_count = required_layers.len,
        //.enabled_layer_count = 0,
        .pp_enabled_layer_names = &required_layers,
        .enabled_extension_count = @intCast(u32, Platform.required_exts.len),
        .pp_enabled_extension_names = @ptrCast([*]const [*:0]const u8, &Platform.required_exts),
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
    surface = try Platform.createWindowSurface(vki, instance, window);
    errdefer vki.destroySurfaceKHR(instance, surface, null);

    // create a device
    // load dispatch functions which require device
    device = try Device.init(.{
        .graphics = true,
        .present = true,
        .transfer = true,
        .discrete = false,
        .compute = true,
    }, instance, vki, surface, allocator);
    errdefer device.deinit();

    swapchain = try Swapchain.init(vki, device, surface, fb_width, fb_height, allocator);
    errdefer swapchain.deinit(device, allocator);

    // subscribe to resize events

    // create a default_renderpass
    default_renderpass = try RenderPass.init(swapchain, device, .{ .offset = .{ .x = 0, .y = 0 }, .extent = .{
        .width = fb_width,
        .height = fb_height,
    } }, .{
        .color = true,
        .depth = true,
        .stencil = true,
    }, .{ 0, 0, 0.1, 1 }, 1.0, 0);
    errdefer default_renderpass.deinit(device);

    // create framebuffers
    std.log.info("fbw: {} fbh: {}", .{ fb_width, fb_width });
    swapchain_render_targets = try allocator.alloc(RenderTarget, swapchain.img_count);
    for (swapchain_render_targets) |*rt| {
        rt.framebuffer = .null_handle;
    }
    try recreateRenderTargets();

    // create global geometry buffers
    try createGlobalBuffers();

    try Resources.init(device, allocator);

    // create frame objects
    try createDescriptors();

    // allocate the sets
    const layouts = [_]vk.DescriptorSetLayout{global_descriptor_layout};

    // create the descriptor set
    for (global_descriptor_sets) |*gs| {
        try device.vkd.allocateDescriptorSets(device.logical, &.{
            .descriptor_pool = global_descriptor_pool,
            .descriptor_set_count = 1,
            .p_set_layouts = layouts[0..],
        }, @ptrCast([*]vk.DescriptorSet, gs));
    }

    for (frames) |*f, i| {
        f.* = try FrameData.init(device, i);
    }

    // create pipeline
    // try createPipeline();

    // create a texture
    {
        // generate the pattern
        const tex_dimension: u32 = 256;
        const channels: u32 = 4;
        const pixel_count = tex_dimension * tex_dimension;
        var pixels: [pixel_count * channels]u8 = undefined;

        // set to 255
        for (pixels) |*p| {
            p.* = 255;
        }

        var row: usize = 0;
        while (row < tex_dimension) : (row += 1) {
            var col: usize = 0;
            while (col < tex_dimension) : (col += 1) {
                var index = (row * tex_dimension) + col;
                var index_bpp = index * channels;
                if ((col + row) % 4 != 0) {
                    pixels[index_bpp + 0] = 0;
                    pixels[index_bpp + 2] = 0;
                }
            }
        }

        default_texture = try Resources.createTexture(.{
            .width = tex_dimension,
            .height = tex_dimension,
            .channels = channels,
            .flags = .{},
        }, pixels[0..]);

        default_texture_map = try TextureMap.init(device, Resources.textures.get(1));
    }
}

// shutdown the renderer
pub fn deinit() void {

    // wait until rendering is done
    device.vkd.deviceWaitIdle(device.logical) catch {
        unreachable;
    };

    default_texture_map.deinit(device);
    // technically don't need to do this since we destroy the texture
    // in the next line
    Resources.destroy(default_texture);

    Resources.deinit();
    destroyBuffers();
    pipeline.deinit(device);

    for (frames) |*f| {
        f.deinit(device);
    }

    // TODO: make this a resource which will delete free descriptorsets
    device.vkd.destroyDescriptorPool(device.logical, global_descriptor_pool, null);
    device.vkd.destroyDescriptorSetLayout(device.logical, global_descriptor_layout, null);

    default_renderpass.deinit(device);
    swapchain.deinit(device, allocator);
    for (swapchain_render_targets) |*rt| {
        rt.deinit(device, allocator);
    }
    allocator.free(swapchain_render_targets);

    device.deinit();

    vki.destroySurfaceKHR(instance, surface, null);

    vki.destroyDebugUtilsMessengerEXT(instance, messenger, null);
    vki.destroyInstance(instance, null);
}

pub fn onResize(w: u32, h: u32) void {
    size_gen += 1;
    std.log.warn("resize triggered: {}x{}, gen: {}", .{ w, h, size_gen });
    fb_width = w;
    fb_height = h;
}

pub fn beginFrame() !bool {
    if (recreating_swapchain) {
        std.log.info("waiting for swapchain", .{});
        try device.vkd.deviceWaitIdle(device.logical);
        return false;
    }

    if (size_gen != last_size_gen) {
        try device.vkd.deviceWaitIdle(device.logical);

        if (!try recreateSwapchain()) {
            return false;
        }

        std.log.info("resized, booting frame", .{});
        return false;
    }

    // wait for current frame
    //std.log.info("waiting for render fence: {}", .{getCurrentFrame().render_fence.handle});
    try getCurrentFrame().render_fence.wait(device, std.math.maxInt(u64));

    image_index = swapchain.acquireNext(device, getCurrentFrame().image_available, Fence{}) catch |err| {
        switch (err) {
            error.OutOfDateKHR => {
                std.log.warn("failed to aquire, booting", .{});
                return false;
            },
            else => |narrow| return narrow,
        }
    };

    try getCurrentFrame().render_fence.reset(device);
    //std.log.debug("image idx: {}", .{image_index});

    return true;
}

/// subit a command buffer
pub fn submit(cmdbuf: CmdBuf) !void {
    var cb: *CommandBuffer = &getCurrentFrame().cmdbuf;
    cb.reset();
    try cb.begin(device, .{});

    var i: usize = 0;
    while (i < cmdbuf.idx) : (i += 1) {
        switch (cmdbuf.commands[i]) {
            .Draw => |desc| applyDraw(cb, desc),
            .BeginRenderPass => |handle| applyBeginRenderPass(cb, handle),
            .EndRenderPass => |handle| applyEndRenderPass(cb, handle),
            .BindPipeline => |handle| try applyBindPipeline(cb, handle),
        }
    }

    try cb.end(device);
}

fn applyBindPipeline(cb: *CommandBuffer, handle: types.Handle) !void {
    _ = handle;

    device.vkd.cmdBindPipeline(cb.handle, .graphics, pipeline.handle);

    // push some constants to this bih
    device.vkd.cmdPushConstants(
        cb.handle,
        pipeline.layout,
        .{ .vertex_bit = true },
        0,
        @intCast(u32, @sizeOf(MeshPushConstants)),
        &push_constant,
    );

    // this is some material system shit
    try updateDescriptorSets();

    const descriptor_sets = [_]vk.DescriptorSet{
        global_descriptor_sets[getCurrentFrame().index],
    };

    device.vkd.cmdBindDescriptorSets(
        cb.handle,
        .graphics,
        pipeline.layout,
        0,
        descriptor_sets.len,
        &descriptor_sets,
        0,
        undefined,
    );
}

fn applyBeginRenderPass(cb: *CommandBuffer, handle: types.Handle) void {
    _ = handle;
    // set the viewport
    const viewport = vk.Viewport{
        .x = 0,
        .y = @intToFloat(f32, fb_height),
        .width = @intToFloat(f32, fb_width),
        .height = -@intToFloat(f32, fb_height),
        .min_depth = 0,
        .max_depth = 1,
    };
    device.vkd.cmdSetViewport(cb.handle, 0, 1, @ptrCast([*]const vk.Viewport, &viewport));

    // set the scissor (region we are clipping)
    const scissor = vk.Rect2D{
        .offset = .{ .x = 0, .y = 0 },
        .extent = .{
            .width = fb_width,
            .height = fb_height,
        },
    };

    device.vkd.cmdSetScissor(cb.handle, 0, 1, @ptrCast([*]const vk.Rect2D, &scissor));

    default_renderpass.begin(device, cb, swapchain_render_targets[image_index].framebuffer);
}

fn applyEndRenderPass(cb: *CommandBuffer, handle: types.Handle) void {
    _ = handle;
    default_renderpass.end(device, cb);
}

fn applyDraw(cb: *CommandBuffer, desc: types.DrawDesc) void {
    const offsets = [_]vk.DeviceSize{ 0, 4 * @sizeOf(Vec3) };
    const buffers = [_]vk.Buffer{
        Resources.getBuffer(desc.vertex_handle).handle,
        Resources.getBuffer(desc.vertex_handle).handle,
    };
    device.vkd.cmdBindVertexBuffers(
        cb.handle,
        0,
        2,
        @ptrCast([*]const vk.Buffer, buffers[0..]),
        offsets[0..],
    );

    device.vkd.cmdBindIndexBuffer(
        cb.handle,
        Resources.getBuffer(desc.index_handle).handle,
        0,
        .uint32,
    );

    device.vkd.cmdDrawIndexed(cb.handle, desc.count, 1, 0, 0, 0);
}

pub fn endFrame() !void {
    var cb: *CommandBuffer = &getCurrentFrame().cmdbuf;

    // waits for the this stage to write
    const wait_stage = [_]vk.PipelineStageFlags{.{ .color_attachment_output_bit = true }};

    try device.vkd.queueSubmit(device.graphics.?.handle, 1, &[_]vk.SubmitInfo{.{
        .command_buffer_count = 1,
        .p_command_buffers = @ptrCast([*]const vk.CommandBuffer, &cb.handle),

        // signaled when queue is complete
        .signal_semaphore_count = 1,
        .p_signal_semaphores = getCurrentFrame().render_finished.ptr(),

        // wait for this before we start
        .wait_semaphore_count = 1,
        .p_wait_semaphores = getCurrentFrame().image_available.ptr(),

        .p_wait_dst_stage_mask = &wait_stage,
    }}, getCurrentFrame().render_fence.handle);

    cb.updateSubmitted();

    // present that shit
    swapchain.present(device, device.present.?, getCurrentFrame().render_finished, @intCast(u32, image_index)) catch |err| {
        switch (err) {
            error.OutOfDateKHR => {
                std.log.warn("swapchain out of date in end frame", .{});
            },
            else => |narrow| return narrow,
        }
    };

    frame_number += 1;
}

// TODO: find a home for this in pipeline
pub fn createPipeline(desc: types.PipelineDesc) !void {
    _ = desc;
    const viewport = vk.Viewport{ .x = 0, .y = @intToFloat(f32, fb_height), .width = @intToFloat(f32, fb_width), .height = -@intToFloat(f32, fb_height), .min_depth = 0, .max_depth = 1 };

    const scissor = vk.Rect2D{
        .offset = .{ .x = 0, .y = 0 },
        .extent = .{
            .width = fb_width,
            .height = fb_height,
        },
    };

    pipeline = try Pipeline.init(
        device,
        desc,
        default_renderpass,
        &[_]vk.DescriptorSetLayout{global_descriptor_layout},
        &[_]vk.PushConstantRange{
            .{
                .stage_flags = .{ .vertex_bit = true },
                .offset = 0,
                .size = @intCast(u32, @sizeOf(MeshPushConstants)),
            },
        },
        viewport,
        scissor,
        false,
        allocator,
    );
}

// helpers

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
    return vk.FALSE;
}

// TODO: move to render target stuff
pub fn recreateRenderTargets() !void {
    std.log.info("fbw: {} fbh: {}", .{ fb_width, fb_height });
    for (swapchain.render_textures) |tex, i| {
        const attachments = [_]Texture{ tex, swapchain.depth_texture };

        swapchain_render_targets[i].reset(device);

        try swapchain_render_targets[i].init(
            device,
            default_renderpass.handle,
            attachments[0..],
            fb_width,
            fb_height,
            allocator,
        );
    }
}

fn recreateSwapchain() !bool {
    if (recreating_swapchain) {
        std.log.warn("already recreating", .{});
        return false;
    }

    if (fb_width == 0 or fb_height == 0) {
        std.log.info("dimesnsion is zero so, no", .{});
        return false;
    }

    recreating_swapchain = true;
    std.log.info("recreating swapchain", .{});

    try device.vkd.deviceWaitIdle(device.logical);
    std.log.info("device done waiting", .{});

    try swapchain.recreate(vki, device, surface, fb_width, fb_height, allocator);

    last_size_gen = size_gen;

    // destroy the sync objects
    for (frames) |*f| {
        f.render_fence.deinit(device);
        f.cmdbuf.deinit(device, device.command_pool);
    }

    // create the framebuffers
    try recreateRenderTargets();

    // create the command buffers
    for (frames) |*f| {
        f.render_fence = try Fence.init(device, true);
        f.cmdbuf = try CommandBuffer.init(device, device.command_pool, true);
    }

    // reset the default_renderpass
    default_renderpass.render_area = .{ .offset = .{ .x = 0, .y = 0 }, .extent = .{
        .width = fb_width,
        .height = fb_height,
    } };

    recreating_swapchain = false;
    std.log.info("done recreating swapchain", .{});

    return true;
}

/// creates the global buffers
fn createGlobalBuffers() !void {
    global_buffer = try Buffer.init(device, @sizeOf(GlobalData), .{ .transfer_dst_bit = true, .uniform_buffer_bit = true }, .{
        .host_visible_bit = true,
        .host_coherent_bit = true,
    }, true);

    material_buffer = try Buffer.init(device, @sizeOf(MaterialData) * 1024, .{ .transfer_dst_bit = true, .uniform_buffer_bit = true }, .{
        .host_visible_bit = true,
        .host_coherent_bit = true,
    }, true);

    // TODO: chagne default size from 1kb
    storage_buffer = try Buffer.init(device, 1024, .{
        .storage_buffer_bit = true,
        .transfer_dst_bit = true,
    }, .{
        .host_visible_bit = true,
        .host_coherent_bit = true,
    }, true);

    try storage_buffer.load(device, Vec3, &[_]Vec3{
        Vec3.new(-0.5, -0.5, 0),
        Vec3.new(0.5, 0.5, 0),
        Vec3.new(-0.5, 0.5, 0),
        Vec3.new(0.5, -0.5, 0),
    }, 0);
    try storage_buffer.load(device, Vec2, &[_]Vec2{
        Vec2.new(0.0, 0.0),
        Vec2.new(1.0, 1.0),
        Vec2.new(0.0, 1.0),
        Vec2.new(1.0, 0.0),
    }, 4 * @sizeOf(Vec3));
}

fn destroyBuffers() void {
    global_buffer.deinit(device);
    storage_buffer.deinit(device);
    material_buffer.deinit(device);
}

fn upload(pool: vk.CommandPool, buffer: Buffer, comptime T: type, items: []const T) !void {
    const size = @sizeOf(T) * items.len;
    const staging_buffer = try Buffer.init(
        device,
        size,
        .{ .transfer_src_bit = true },
        .{ .host_visible_bit = true, .host_coherent_bit = true },
        true,
    );
    defer staging_buffer.deinit(device);

    try staging_buffer.load(device, T, items, 0);

    try Buffer.copyTo(device, pool, device.graphics.?, staging_buffer, 0, buffer, 0, size);
}

fn createDescriptors() !void {
    // create a descriptor pool for the frame data
    const global_sizes = [_]vk.DescriptorPoolSize{
        // constants
        .{
            .@"type" = .uniform_buffer,
            .descriptor_count = frames.len,
        },
        // data
        .{
            .@"type" = .storage_buffer,
            .descriptor_count = frames.len,
        },
        // images
        .{
            .@"type" = .sampled_image,
            .descriptor_count = frames.len,
        },
        // samplers
        .{
            .@"type" = .sampler,
            .descriptor_count = frames.len,
        },
    };

    global_descriptor_pool = try device.vkd.createDescriptorPool(device.logical, &.{
        .flags = .{},
        .max_sets = frames.len,
        .pool_size_count = global_sizes.len,
        .p_pool_sizes = &global_sizes,
    }, null);

    // for now we set all the # descriptors be 1024 and usable in all stages

    const global_bindings = [_]vk.DescriptorSetLayoutBinding{
        // constant data
        .{
            .binding = 0,
            .descriptor_type = .uniform_buffer,
            .descriptor_count = 1024,
            .stage_flags = .{
                .vertex_bit = true,
                .fragment_bit = true,
                .compute_bit = true,
            },
            .p_immutable_samplers = null,
        },
        // larger storage
        .{
            .binding = 1,
            .descriptor_type = .storage_buffer,
            .descriptor_count = 1024,
            .stage_flags = .{
                .vertex_bit = true,
                .fragment_bit = true,
                .compute_bit = true,
            },
            .p_immutable_samplers = null,
        },
        // sampled image
        .{
            .binding = 2,
            .descriptor_type = .sampled_image,
            .descriptor_count = 1024,
            .stage_flags = .{
                .vertex_bit = true,
                .fragment_bit = true,
                .compute_bit = true,
            },
            .p_immutable_samplers = null,
        },
        // sampler for the image
        .{
            .binding = 3,
            .descriptor_type = .sampler,
            .descriptor_count = 1024,
            .stage_flags = .{
                .vertex_bit = true,
                .fragment_bit = true,
                .compute_bit = true,
            },
            .p_immutable_samplers = null,
        },
    };

    const binding_flags = [_]vk.DescriptorBindingFlags{.{ .partially_bound_bit = true }} ** global_bindings.len;

    // flags for the descriptor sets
    const binding_flags_info = vk.DescriptorSetLayoutBindingFlagsCreateInfo{
        .binding_count = global_bindings.len,
        .p_binding_flags = &binding_flags,
    };

    global_descriptor_layout = try device.vkd.createDescriptorSetLayout(device.logical, &.{
        .flags = .{},
        .binding_count = global_bindings.len,
        .p_bindings = &global_bindings,
        .p_next = &binding_flags_info,
    }, null);
}

fn updateDescriptorSets() !void {
    try global_buffer.load(device, GlobalData, &[_]GlobalData{cam_data}, 0);
    try material_buffer.load(device, MaterialData, &[_]MaterialData{.{
        .albedo = Vec3.new(1, 1, 1),
    }}, 0);

    // TODO: this should only update what actually needs it

    const cam_infos = [_]vk.DescriptorBufferInfo{
        .{
            .buffer = global_buffer.handle,
            .offset = 0,
            .range = @sizeOf(GlobalData),
        },
    };

    const sampler_infos = [_]vk.DescriptorImageInfo{
        .{
            .sampler = .null_handle,
            .image_view = Resources.textures.get(1).image.view,
            .image_layout = vk.ImageLayout.shader_read_only_optimal,
        },
        .{
            .sampler = default_texture_map.sampler,
            .image_view = Resources.textures.get(1).image.view,
            .image_layout = .@"undefined",
        },
    };

    // maps the vertex position to a descriptor
    const storage_infos = [_]vk.DescriptorBufferInfo{
        .{
            .buffer = storage_buffer.handle,
            .offset = 0,
            .range = 4 * @sizeOf(Vec3),
        },
        .{
            .buffer = storage_buffer.handle,
            .offset = 4 * @sizeOf(Vec3),
            .range = 4 * @sizeOf(Vec2),
        },
    };

    const writes = [_]vk.WriteDescriptorSet{
        .{
            .dst_set = global_descriptor_sets[getCurrentFrame().index],
            .dst_binding = 0,
            .dst_array_element = 0,
            .descriptor_count = cam_infos.len,
            .descriptor_type = .uniform_buffer,
            .p_image_info = undefined,
            .p_buffer_info = cam_infos[0..],
            .p_texel_buffer_view = undefined,
        },
        .{
            .dst_set = global_descriptor_sets[getCurrentFrame().index],
            .dst_binding = 1,
            .dst_array_element = 0,
            .descriptor_count = storage_infos.len,
            .descriptor_type = .storage_buffer,
            .p_image_info = undefined,
            .p_buffer_info = storage_infos[0..],
            .p_texel_buffer_view = undefined,
        },
        // .{
        //     .dst_set = global_descriptor_sets[getCurrentFrame().index],
        //     .dst_binding = 1,
        //     .dst_array_element = 1,
        //     .descriptor_count = 1,
        //     .descriptor_type = .storage_buffer,
        //     .p_image_info = undefined,
        //     .p_buffer_info = storage_infos[1..],
        //     .p_texel_buffer_view = undefined,
        // },
        .{
            .dst_set = global_descriptor_sets[getCurrentFrame().index],
            .dst_binding = 2,
            .dst_array_element = 0,
            .descriptor_count = 1,
            .descriptor_type = .sampled_image,
            .p_image_info = sampler_infos[0..],
            .p_buffer_info = undefined,
            .p_texel_buffer_view = undefined,
        },
        .{
            .dst_set = global_descriptor_sets[getCurrentFrame().index],
            .dst_binding = 3,
            .dst_array_element = 0,
            .descriptor_count = 1,
            .descriptor_type = .sampler,
            .p_image_info = sampler_infos[1..],
            .p_buffer_info = undefined,
            .p_texel_buffer_view = undefined,
        },
    };

    device.vkd.updateDescriptorSets(device.logical, writes.len, &writes, 0, undefined);
}

/// Returns the framedata of the frame we should be on
inline fn getCurrentFrame() *FrameData {
    return &frames[frame_number % frames.len];
}

/// What you need for a single frame
const FrameData = struct {
    // what number frame is this?
    index: usize,
    /// Semaphore signaled when the frame is finished rendering
    render_finished: Semaphore,
    /// semaphore signaled when the frame has been presented by the framebuffer
    image_available: Semaphore,
    /// fence to wait on for this frame to finish rendering
    render_fence: Fence,

    // maybe add a command pool?
    /// Command buffer for this frame
    /// TODO: add a cmdbuf for offscreen rendering and then use this one for rendering to the screen
    cmdbuf: CommandBuffer,

    const Self = @This();

    pub fn init(dev: Device, index: usize) !Self {
        var self: Self = undefined;

        self.index = index;

        self.image_available = try Semaphore.init(dev);
        errdefer self.image_available.deinit(dev);

        self.render_finished = try Semaphore.init(dev);
        errdefer self.render_finished.deinit(dev);

        self.render_fence = try Fence.init(dev, true);
        errdefer self.render_fence.deinit(dev);

        self.cmdbuf = try CommandBuffer.init(dev, dev.command_pool, true);
        errdefer self.cmdbuf.deinit(dev, dev.command_pool);
        return self;
    }

    pub fn deinit(self: *Self, dev: Device) void {
        self.image_available.deinit(dev);
        self.render_finished.deinit(dev);
        self.render_fence.deinit(dev);
        self.cmdbuf.deinit(dev, dev.command_pool);
    }
};
