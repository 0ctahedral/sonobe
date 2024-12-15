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

    var window = try platform.Window.init("playground");

    try gpu.init();
    defer gpu.deinit();

    window.surface = try gpu.createSurface(window.window);
    const device = try gpu.createDevice(allocator, window.surface.?);
    defer device.deinit();

    var swapchain = try gpu.createSwapchain();
    defer swapchain.deinit();

    var runtime = Runtime{};
    try runtime.init();
    defer runtime.deinit();

    try runtime.loop();
}
