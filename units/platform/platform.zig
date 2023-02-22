const std = @import("std");
const utils = @import("utils");
const log = utils.log.Logger("platform");
pub const events = @import("events.zig");
pub const input = @import("input.zig");
const Handle = utils.Handle;
const Vec2 = @import("math").Vec2;

const backend = @import("macos.zig");

pub var is_running = true;

const frame_time = struct {
    var timer: std.time.Timer = undefined;
    var delta: f32 = 0;
    var prev_ns: u64 = 0;
    var fps: f32 = 0;
};

pub var frame_number: u64 = 0;

pub const PlatformSettings = struct {};

/// Initialize the platform layer
pub inline fn init(settings: PlatformSettings) !void {
    // start the timer
    frame_time.timer = try std.time.Timer.start();

    try backend.init(settings);
}

/// shutdown the platform layer
pub inline fn deinit() void {
    backend.deinit();
}
/// poll for input events on this platform
pub inline fn poll() void {
    backend.poll();
}

pub inline fn createWindow(title: []const u8, width: u32, height: u32) anyerror!Handle(.Window) {
    return backend.createWindow(title, width, height);
}

pub inline fn setWindowTitle(win: Handle(.Window), title: []const u8) !void {
    return backend.setWindowTitle(win, title);
}

pub inline fn getWindowSize(win: Handle(.Window)) Vec2 {
    return backend.getWindowSize(win);
}

/// starts a frame: used for tracking delta time and stuff
pub fn startFrame() void {
    const now = frame_time.timer.read();

    frame_time.delta = @intToFloat(f32, now - frame_time.prev_ns) / std.time.ns_per_s;

    frame_time.prev_ns = now;

    const t = @intToFloat(f32, now) / std.time.ns_per_s;
    frame_time.fps = @intToFloat(f32, frame_number) / t;
}

/// ends a frame: used for tracking delta time and stuff
pub fn endFrame() void {
    frame_number += 1;
}

/// the delta time for the current frame in seconds
pub inline fn dt() f32 {
    return frame_time.delta;
}

/// the fps based on delta time for current frame
pub inline fn fps() f32 {
    return frame_time.fps;
}

// vulkan stuff

// libvk = try std.DynLib.open(vkdl);

// if (libvk.lookup(vk.PfnGetInstanceProcAddr, "vkGetInstanceProcAddr")) |pfn| {
//     vk_get_proc = pfn;
// } else {
//     return error.CouldNotLoadVulkan;
// }

// const builtin = @import("builtin");
// /// the vulkan dynamic library
// var libvk: std.DynLib = undefined;
// /// function pointer to vulkan proc
// var vk_get_proc: vk.PfnGetInstanceProcAddr = undefined;
//
// pub const vkdl = switch (builtin.target.os.tag) {
//     .macos => "./deps/vulkan/macos/lib/libvulkan.dylib",
//     .linux => "./deps/vulkan/x86_64/lib/libvulkan.so",
//     else => unreachable,
// };
//
// pub const required_exts = [_][*:0]const u8{
//     vk.extension_info.ext_debug_utils.name,
//     "VK_KHR_surface",
//     switch (builtin.target.os.tag) {
//         .macos => "VK_EXT_metal_surface",
//         .linux => "VK_KHR_xcb_surface",
//         else => unreachable,
//     },
// };
//
//
// /// get the vulkan instance address
// pub fn getInstanceProcAddress() fn (vk.Instance, [*:0]const u8) callconv(.C) vk.PfnVoidFunction {
//     //TODO: sanity checks (if it is this function, or empty)
//     return vk_get_proc;
// }
//
// pub fn createWindowSurface(vki: InstanceDispatch, instance: vk.Instance, window: Window) !vk.SurfaceKHR {
//     return backend.createWindowSurface(vki, instance, window);
// }
//
