const std = @import("std");
const vk = @import("vulkan");
const Allocator = std.mem.Allocator;

// other modules in the engine
const Platform = @import("platform.zig");
const Events = @import("events.zig");
const mmath = @import("math.zig");
const Mat4 = mmath.Mat4;
const Vec3 = mmath.Vec3;
const containers = @import("./containers.zig");
const FreeList = containers.FreeList;
const Cache = containers.Cache;

// TODO: should this be its own module?
pub const mesh = @import("./renderer/mesh.zig");

// Internal types
const dispatch_types = @import("./renderer/dispatch_types.zig");
const BaseDispatch = dispatch_types.BaseDispatch;
const InstanceDispatch = dispatch_types.InstanceDispatch;

// public internal types
pub const Device = @import("./renderer/device.zig").Device;
pub const Queue = @import("./renderer/device.zig").Queue;
pub const Swapchain = @import("./renderer/swapchain.zig").Swapchain;
pub const RenderPass = @import("./renderer/renderpass.zig").RenderPass;
pub const RenderPassInfo = @import("./renderer/renderpass.zig").RenderPassInfo;
pub const CommandBuffer = @import("./renderer/commandbuffer.zig").CommandBuffer;
pub const Fence = @import("./renderer/fence.zig").Fence;
pub const Semaphore = @import("./renderer/semaphore.zig").Semaphore;
pub const Shader = @import("./renderer/shader.zig").Shader;
pub const Pipeline = @import("./renderer/pipeline.zig").Pipeline;
pub const Buffer = @import("./renderer/buffer.zig").Buffer;

// TODO: set this in a config
const required_layers = [_][*:0]const u8{"VK_LAYER_KHRONOS_validation"};

// dispatch for vulkan
var vkb: BaseDispatch = undefined;
var vki: InstanceDispatch = undefined;

/// Vulkan Instance
var instance: vk.Instance = undefined;
// TODO: this should belong to the window
/// Surface of main window
var surface: vk.SurfaceKHR = undefined;
/// debug messenger
var messenger: vk.DebugUtilsMessengerEXT = undefined;
/// the device we are using
pub var device: Device = undefined;
/// Allocator used by the renderer
var allocator: Allocator = undefined;

// TODO: should this belong to the window?
/// swapchain for rendering images
pub var swapchain: Swapchain = undefined;

/// monotonically increasing frame number
pub var frame_number: usize = 0;

// TODO: make this part of the frame struct
/// index of the image in the swapchain we are currently
/// rendering to
pub var image_index: usize = 0;

/// generation of this resize
var size_gen: usize = 0;
var last_size_gen: usize = 0;

/// cached dimensions of the framebuffer
var cached_width: u32 = 0;
var cached_height: u32 = 0;

// TODO: should this be the job of the platform?
/// current dimesnsions of the framebuffer
pub var fb_width: u32 = 0;
pub var fb_height: u32 = 0;

/// The currently rendering frames
var frames: [2]FrameData = undefined;

/// Returns the framedata of the frame we should be on
pub inline fn getCurrentFrame() *FrameData {
    return &frames[frame_number % frames.len];
}

// initialize the renderer
pub fn init(provided_allocator: Allocator, app_name: [*:0]const u8, window: Platform.Window) !void {
    allocator = provided_allocator;

    var vk_proc = Platform.getInstanceProcAddress();

    // get proc address from glfw window
    // load the base dispatch functions
    vkb = try BaseDispatch.load(vk_proc);

    //const winsize = try Platform.getWinSize();
    cached_width = 0;
    cached_height = 0;

    fb_width = if (cached_width != 0) cached_width else 800;
    fb_height = if (cached_height != 0) cached_height else 600;
    cached_width = 0;
    cached_height = 0;

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
        .transfer = false,
        .discrete = false,
        .compute = false,
    }, instance, vki, surface, allocator);
    errdefer device.deinit();

    swapchain = try Swapchain.init(vki, device, surface, fb_width, fb_height, allocator);
    errdefer swapchain.deinit(device, allocator);

    // subscribe to resize events
    try Events.register(Events.EventType.WindowResize, resize);

    // create a buffer manager
    // TODO: buffer limits and stuff
    // should we just be suballocating one buffer?
    buffer_manager = try FreeList(Buffer).init(allocator, 10);


    // setup caches
    renderpass_cache.init(allocator);
    fb_cache.init(allocator);

    pipeline_cache.init(allocator);

    // HERE IS WHERE SETUP SHOULD END

    // descriptors should be created by the pipeline
    try createDescriptors();

    // create frame objects
    for (frames) |*f| {
        f.* = try FrameData.init(device, global_descriptor_pool, global_descriptor_layout);
    }
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
    return vk.FALSE;
}

// shutdown the renderer
pub fn deinit() void {

    // wait until rendering is done
    device.vkd.deviceWaitIdle(device.logical) catch {
        unreachable;
    };


    for (frames) |*f| {
        f.deinit(device);
    }
    var iter = buffer_manager.iter();
    while (iter.next()) |buf| {
        buf.deinit(device);
    }
    buffer_manager.deinit();

    device.vkd.destroyDescriptorPool(device.logical, global_descriptor_pool, null);
    device.vkd.destroyDescriptorSetLayout(device.logical, global_descriptor_layout, null);


    renderpass_cache.deinit();

    fb_cache.deinit();

    pipeline_cache.deinit();

    swapchain.deinit(device, allocator);

    device.deinit();

    vki.destroySurfaceKHR(instance, surface, null);

    vki.destroyDebugUtilsMessengerEXT(instance, messenger, null);
    vki.destroyInstance(instance, null);
}

fn resize(ev: Events.Event) void {
    const w = ev.WindowResize.w;
    const h = ev.WindowResize.h;
    cached_width = w;
    cached_height = h;
    fb_width = w;
    fb_height = h;
    size_gen += 1;
    std.log.warn("resize triggered: {}x{}, gen: {}", .{ w, h, size_gen });
}

/// aquires next image
pub fn beginFrame() !void {
    if (size_gen != last_size_gen) {
        try device.vkd.deviceWaitIdle(device.logical);
        try recreateSwapchain();
        std.log.info("resized, booting frame", .{});
        getCurrentFrame().*.begun = false;
        return;
    }

    try getCurrentFrame().render_fence.wait(device, std.math.maxInt(u64));

    if (swapchain.acquireNext(device, getCurrentFrame().image_avail_semaphore, Fence{})) |idx| {
        image_index = idx;
    } else |err| {
        switch (err) {
            error.OutOfDateKHR => {
                std.log.warn("failed to aquire, booting", .{});
                _ = try recreateSwapchain();
                getCurrentFrame().*.begun = false;
                return;
            },
            else => |narrow| return narrow,
        }
    }

    // reset the fence now that we've waited for it
    try getCurrentFrame().render_fence.reset(device);
    getCurrentFrame().*.begun = true;
}

pub fn endFrame() !void {
    if (!getCurrentFrame().begun) {
        return;
    }
    var cb: *CommandBuffer = &getCurrentFrame().cmdbuf;

    // waits for the this stage to write
    const wait_stage = [_]vk.PipelineStageFlags{.{ .color_attachment_output_bit = true }};

    try device.vkd.queueSubmit(device.graphics.?.handle, 1, &[_]vk.SubmitInfo{.{
        .command_buffer_count = 1,
        .p_command_buffers = @ptrCast([*]const vk.CommandBuffer, &cb.handle),

        // signaled when queue is complete
        .signal_semaphore_count = 1,
        .p_signal_semaphores = getCurrentFrame().queue_complete_semaphore.ptr(),

        // wait for this before we start
        .wait_semaphore_count = 1,
        .p_wait_semaphores = getCurrentFrame().image_avail_semaphore.ptr(),

        .p_wait_dst_stage_mask = &wait_stage,
    }}, getCurrentFrame().render_fence.handle);

    cb.updateSubmitted();

    // present that shit
    swapchain.present(device, device.present.?, getCurrentFrame().queue_complete_semaphore, @intCast(u32, image_index)) catch |err| {
        switch (err) {
            error.SuboptimalKHR, error.OutOfDateKHR => {
                std.log.warn("swapchain out of date in end frame", .{});
            },
            else => |narrow| return narrow,
        }
    };

    frame_number += 1;
}

fn recreateSwapchain() !void {
    if (cached_width == 0 or cached_height == 0) {
        std.log.info("dimesnsion is zero so, no", .{});
        return;
    }

    std.log.info("recreating swapchain", .{});

    try device.vkd.deviceWaitIdle(device.logical);
    std.log.info("device done waiting", .{});

    try swapchain.recreate(vki, device, surface, cached_width, cached_height, allocator);

    fb_width = cached_width;
    fb_height = cached_height;

    cached_width = 0;
    cached_height = 0;

    last_size_gen = size_gen;

    // destroy the sync objects
    for (frames) |*f| {
        f.render_fence.deinit(device);
        f.cmdbuf.deinit(device, device.command_pool);
    }

    // destroy old framebuffers
    fb_cache.clear();

    // create the command buffers
    for (frames) |*f| {
        f.render_fence = try Fence.init(device, true);
        f.cmdbuf = try CommandBuffer.init(device, device.command_pool, true);
    }

    std.log.info("done recreating swapchain", .{});

}

// caches and managers of that sort
/// cache for renderpasses
pub var renderpass_cache = Cache(RenderPassInfo, RenderPass, RenderPassInfo.Context, struct {
    pub fn create (rpi: RenderPassInfo) !RenderPass {
        return RenderPass.init(swapchain, device, rpi);
    }

    pub fn destroy(rp: RenderPass) void {
        rp.deinit(device);
    }
}){};
pub var fb_cache = Cache(RenderPassInfo, vk.Framebuffer, RenderPassInfo.Context, struct {
    pub fn create (rpi: RenderPassInfo) !vk.Framebuffer {
        const attachments = [_]vk.ImageView{
            rpi.color_attachments[0].view,
            rpi.depth_attachment.?.view
        };

        var rp: RenderPass = try renderpass_cache.request(.{rpi});

        return try device.vkd.createFramebuffer(device.logical, &.{
            .flags = .{},
            .render_pass = rp.handle,
            .attachment_count = attachments.len,
            .p_attachments = @ptrCast([*]const vk.ImageView, &attachments),
            .width = fb_width,
            .height = fb_height,
            .layers = 1,
        }, null);
    }
    
    pub fn destroy(fb: vk.Framebuffer) void {
        device.vkd.destroyFramebuffer(device.logical, fb, null);
    }
}
){};

pub var pipeline_cache = Cache(PipelineInfo, Pipeline, null, struct {
    pub const create = createPipeline;

    pub fn destroy(pl: Pipeline) void {
        pl.deinit(device);
    }
}){};

// buffer manager
pub var buffer_manager: FreeList(Buffer) = undefined;





pub const PipelineInfo = struct {
    /// This will be an api around descriptor sets and stuff
    pub const Stage = struct {
        pub const Input = struct {
            type: enum {
                buffer,
            }
        };

        path: []const u8,
        //inputs: []const Input = &[_]Input{},
    };

    vertex: ?Stage,
    fragment: ?Stage,
};

/// Creates a user defined pipeline
pub fn createPipeline(
    info: PipelineInfo,
    rpi: RenderPassInfo,
) !Pipeline {
    // get renderpass
    var rp: RenderPass = try renderpass_cache.request(.{rpi});

    const viewport = vk.Viewport{ .x = 0, .y = @intToFloat(f32, fb_height), .width = @intToFloat(f32, fb_width), .height = -@intToFloat(f32, fb_height), .min_depth = 0, .max_depth = 1 };

    const scissor = vk.Rect2D{
        .offset = .{ .x = 0, .y = 0 },
        .extent = .{
            .width = fb_width,
            .height = fb_height,
        },
    };

    var stage_ci: [3]vk.PipelineShaderStageCreateInfo = undefined;
    var shader_modules: [3]vk.ShaderModule = undefined;
    var n_stages: usize = 0;

    if (info.vertex) |vert| {
        const shader_info = try Shader.createAndLoad(device, vert.path, .{ .vertex_bit = true }, allocator);
        stage_ci[n_stages] = shader_info.info;
        shader_modules[n_stages] = shader_info.module;
        n_stages += 1;
    }
    if (info.fragment) |frag| {
        const shader_info = try Shader.createAndLoad(device, frag.path, .{ .fragment_bit = true }, allocator);
        stage_ci[n_stages] = shader_info.info;
        shader_modules[n_stages] = shader_info.module;
        n_stages += 1;
    }

    const pl = Pipeline.init(device, rp, &[_]vk.DescriptorSetLayout{global_descriptor_layout}, &[_]vk.PushConstantRange{.{
        .stage_flags = .{ .vertex_bit = true },
        .offset = 0,
        .size = @intCast(u32, @sizeOf(MeshPushConstants)),
    }}, stage_ci[0..n_stages], viewport, scissor, false);

    for (shader_modules[0..n_stages]) |stage| {
        device.vkd.destroyShaderModule(device.logical, stage, null);
    }

    return pl;
}






/// descriptor set layout for global data (i.e. camera transform)
var global_descriptor_layout: vk.DescriptorSetLayout = .null_handle;
/// pool from which we allocate all descriptor sets
var global_descriptor_pool: vk.DescriptorPool = .null_handle;

fn createDescriptors() !void {
    // create a descriptor pool for the frame data
    const sizes = [_]vk.DescriptorPoolSize{
        .{
            .@"type" = .uniform_buffer,
            .descriptor_count = frames.len,
        },
        .{
            .@"type" = .storage_buffer,
            .descriptor_count = frames.len,
        },
    };

    global_descriptor_pool = try device.vkd.createDescriptorPool(device.logical, &.{
        .flags = .{},
        .max_sets = frames.len,
        .pool_size_count = sizes.len,
        .p_pool_sizes = &sizes,
    }, null);

    // attempt at bindless aproach
    const global_bindings = [_]vk.DescriptorSetLayoutBinding{
        // camera
        .{
            .binding = 0,
            .descriptor_type = .uniform_buffer,
            .descriptor_count = 1,
            .stage_flags = .{ .vertex_bit = true },
            .p_immutable_samplers = null,
        },
        // storage for model matricies
        .{
            .binding = 1,
            .descriptor_type = .storage_buffer,
            .descriptor_count = 1,
            .stage_flags = .{ .vertex_bit = true },
            .p_immutable_samplers = null,
        },
    };

    global_descriptor_layout = try device.vkd.createDescriptorSetLayout(device.logical, &.{
        .flags = .{},
        .binding_count = global_bindings.len,
        .p_bindings = &global_bindings,
    }, null);
}

pub fn updateUniform(transform: Mat4) void {
    getCurrentFrame().*.model_data[0] = transform;
    getCurrentFrame().updateDescriptorSets(device) catch unreachable;
}

/// Index to look up mesh data in shader
pub const MeshPushConstants = struct {
    index: u32,
};

/// What you need for a single frame
const FrameData = struct {
    /// Semaphore signaled when the frame is finished rendering
    queue_complete_semaphore: Semaphore,
    /// semaphore signaled when the frame has been presented by the swapchain
    image_avail_semaphore: Semaphore,
    /// fence to wait on for this frame to finish rendering
    render_fence: Fence,

    // TODO: maybe add a command pool?
    /// Command buffer for this frame
    cmdbuf: CommandBuffer,

    /// Has this frame begun rendering?
    begun: bool = false,

    // EVERYTHING BELOW HERE SHOULD BE MOVED SOMEWHERE ELSE

    /// descriptor set for this frame
    global_descriptor_set: vk.DescriptorSet,

    /// buffer of data in ds for this frame
    global_buffer: Buffer,

    model_buffer: Buffer,

    cam_data: CameraData,

    model_data: [100]Mat4 = undefined,


    const CameraData = struct {
        projection: Mat4 = Mat4.perspective(mmath.util.rad(70), 800.0/600.0, 0.1, 1000),
        //projection: Mat4 = Mat4.ortho(0, 800.0, 0, 600.0, -100, 100),
        view: Mat4 = Mat4.translate(.{.x=0, .y=0, .z=2}).inv(),
        //view: Mat4 = Mat4.translate(.{ .x = 0, .y = 0, .z = 0 }),
    };

    const Self = @This();

    pub fn init(dev: Device, descriptor_pool: vk.DescriptorPool, layout: vk.DescriptorSetLayout) !Self {
        var self: Self = undefined;

        self.image_avail_semaphore = try Semaphore.init(dev);
        errdefer self.image_avail_semaphore.deinit(dev);

        self.queue_complete_semaphore = try Semaphore.init(dev);
        errdefer self.queue_complete_semaphore.deinit(dev);

        self.render_fence = try Fence.init(dev, true);
        errdefer self.render_fence.deinit(dev);

        self.cmdbuf = try CommandBuffer.init(dev, dev.command_pool, true);
        errdefer self.cmdbuf.deinit(dev, dev.command_pool);

        // create the buffer
        self.global_buffer = try Buffer.init(dev, @sizeOf(CameraData), .{ .transfer_dst_bit = true, .uniform_buffer_bit = true }, .{
            .host_visible_bit = true,
            .host_coherent_bit = true,
        }, true);

        self.model_buffer = try Buffer.init(dev, @sizeOf(@TypeOf(self.model_data)), .{
            .storage_buffer_bit = true,
            .transfer_dst_bit = true,
        }, .{
            .host_visible_bit = true,
            .host_coherent_bit = true,
        }, true);

        // allocate the sets
        const layouts = [_]vk.DescriptorSetLayout{
            layout,
        };

        try dev.vkd.allocateDescriptorSets(dev.logical, &.{
            .descriptor_pool = descriptor_pool,
            .descriptor_set_count = 1,
            .p_set_layouts = layouts[0..],
        }, @ptrCast([*]vk.DescriptorSet, &self.global_descriptor_set));

        self.cam_data = CameraData{};
        self.model_data[0] = Mat4.translate(Vec3.new(0, 100, 0));
        self.model_data[1] = Mat4.scale(mmath.Vec3.new(100, 100, 100))
            .mul(Mat4.translate(.{ .x = 500, .y = 250 }));

        try self.updateDescriptorSets();

        return self;
    }

    pub fn deinit(self: *Self, dev: Device) void {
        self.model_buffer.deinit(dev);
        self.global_buffer.deinit(dev);
        self.image_avail_semaphore.deinit(dev);
        self.queue_complete_semaphore.deinit(dev);
        self.render_fence.deinit(dev);
        self.cmdbuf.deinit(dev, dev.command_pool);
    }

    pub fn updateDescriptorSets(
        self: Self,
    ) !void {
        try self.global_buffer.load(device, CameraData, &[_]CameraData{self.cam_data}, 0);
        try self.model_buffer.load(device, Mat4, self.model_data[0..], 0);

        const cam_infos = [_]vk.DescriptorBufferInfo{
            .{
                .buffer = self.global_buffer.handle,
                .offset = 0,
                .range = @sizeOf(CameraData),
            },
        };
        const model_infos = [_]vk.DescriptorBufferInfo{
            .{
                .buffer = self.model_buffer.handle,
                .offset = 0,
                .range = @sizeOf(@TypeOf(self.model_data)),
            },
        };

        const writes = [_]vk.WriteDescriptorSet{ .{
            .dst_set = self.global_descriptor_set,
            .dst_binding = 0,
            .dst_array_element = 0,
            .descriptor_count = cam_infos.len,
            .descriptor_type = .uniform_buffer,
            .p_image_info = undefined,
            .p_buffer_info = cam_infos[0..],
            .p_texel_buffer_view = undefined,
        }, .{
            .dst_set = self.global_descriptor_set,
            .dst_binding = 1,
            .dst_array_element = 0,
            .descriptor_count = model_infos.len,
            .descriptor_type = .storage_buffer,
            .p_image_info = undefined,
            .p_buffer_info = model_infos[0..],
            .p_texel_buffer_view = undefined,
        } };

        device.vkd.updateDescriptorSets(device.logical, writes.len, &writes, 0, undefined);
    }
};

