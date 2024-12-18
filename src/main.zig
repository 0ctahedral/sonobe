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

    // framebuffers

    // command pool
    //
    // vertex buffer
    // create and bind
    // upload vertices

    // create command buffers

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
