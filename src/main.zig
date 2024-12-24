const std = @import("std");
const core = @import("core.zig");
pub const log = core.logger.Logger("platform");
// this will eventually be able to do this
// const platform = @import("platform");
const platform = @import("platform.zig");
const gpu = @import("gpu.zig");

const Runtime = @import("Runtime.zig");

const posix = std.posix;
const SIG = posix.system.SIG;

pub fn main() !void {

    // TODO: each system gets its own arena allocator from the top level allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    try platform.init();
    defer platform.deinit();

    var window = try platform.Window.init("playground", 800, 600);

    try gpu.init(allocator);
    defer gpu.deinit();

    window.surface = try gpu.createSurface(window.window);
    const device = try gpu.createDevice(window.surface.?);
    defer device.deinit();

    var swapchain = try gpu.createSwapchain(device, window);
    defer swapchain.deinit();

    // renderpass
    log.info("creating renderpass", .{});
    const render_pass = try gpu.createRenderPass(device, &swapchain);
    defer device.dev.destroyRenderPass(render_pass, null);

    // pipeline layout
    log.info("creating pipeline layout", .{});
    const pipeline_desc = gpu.pipeline.PipelineDesc{};
    // pipeline itself
    const pipeline = try gpu.createPipeline(device, pipeline_desc, render_pass);
    defer pipeline.deinit(device);

    // framebuffers for renderpass (one to reference each swapchain imageview)
    const framebuffers = try gpu.createFrameBuffers(device, &swapchain, render_pass);
    defer gpu.destroyFrameBuffers(device, framebuffers);

    // command pool
    const pool = try device.dev.createCommandPool(&.{
        .queue_family_index = device.graphics.?.family,
    }, null);
    defer device.dev.destroyCommandPool(pool, null);


    const vertices = [_]gpu.Vertex{
        .{ .pos = .{ 0, -0.5 }, .color = .{ 1, 0, 0 } },
        .{ .pos = .{ 0.5, 0.5 }, .color = .{ 0, 1, 0 } },
        .{ .pos = .{ -0.5, 0.5 }, .color = .{ 0, 0, 1 } },
    };

    // vertex buffer
    // create and bind
    const vertex_buffer_buffer = try device.dev.createBuffer(&.{
        .size = @sizeOf(@TypeOf(vertices)),
        .usage = .{ .transfer_dst_bit = true, .vertex_buffer_bit = true },
        .sharing_mode = .exclusive,
    }, null);
    defer device.dev.destroyBuffer(vertex_buffer_buffer, null);
    const mem_reqs = device.dev.getBufferMemoryRequirements(vertex_buffer_buffer);
    const memory = try device.allocate(mem_reqs, .{ .device_local_bit = true });
    defer device.dev.freeMemory(memory, null);
    try device.dev.bindBufferMemory(vertex_buffer_buffer, memory, 0);

    // upload vertices
    try gpu.uploadVertices(device, vertices, vertex_buffer_buffer, pool);

    // create command buffers
    const cmdbufs = try gpu.createCommandBuffers(
        device,
        pool,
        framebuffers,
        swapchain.extent,
        render_pass,
        pipeline.handle,
        vertex_buffer_buffer,
        @intCast(vertices.len),
    );
    defer for (cmdbufs) |*cmdbuf| {
        cmdbuf.deinit(device, pool);
    };

    // in the loop:
    // present the current command buffer
    // if swapchain is out of date or size changes:
    // recreate swapchain
    // recreate framebuffers
    // recreate commandbuffers

    var runtime = Runtime{};
    try runtime.init();
    defer runtime.deinit();

    try runtime.loop();
}
