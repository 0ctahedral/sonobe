const std = @import("std");
const utils = @import("utils");
const log = utils.log.Logger("platform");
const builtin = @import("builtin");
const vk = @import("vulkan");
const InstanceDispatch = @import("../device/vulkan/dispatch_types.zig").InstanceDispatch;
pub const events = @import("events.zig");
pub const input = @import("input.zig");

pub const Window = @import("window.zig");

const backend = @import("glfw.zig");

pub var is_running = true;

/// the vulkan dynamic library
var libvk: std.DynLib = undefined;
/// function pointer to vulkan proc
var vk_get_proc: vk.PfnGetInstanceProcAddr = undefined;

pub const vkdl = switch (builtin.target.os.tag) {
    .macos => "./deps/vulkan/macos/lib/libvulkan.dylib",
    .linux => "./deps/vulkan/x86_64/lib/libvulkan.so",
    else => unreachable,
};

pub const required_exts = [_][*:0]const u8{
    vk.extension_info.ext_debug_utils.name,
    "VK_KHR_surface",
    switch (builtin.target.os.tag) {
        .macos => "VK_EXT_metal_surface",
        .linux => "VK_KHR_xcb_surface",
        else => unreachable,
    },
};

const frame_time = struct {
    var timer: std.time.Timer = undefined;
    var delta: f32 = 0;
    var prev_ns: u64 = 0;
    var fps: f32 = 0;
};

pub var frame_number: u64 = 0;

/// Initialize the platform layer
pub fn init() !void {
    libvk = try std.DynLib.open(vkdl);

    if (libvk.lookup(vk.PfnGetInstanceProcAddr, "vkGetInstanceProcAddr")) |pfn| {
        vk_get_proc = pfn;
    } else {
        return error.CouldNotLoadVulkan;
    }

    // start the timer
    frame_time.timer = try std.time.Timer.start();

    // initialize the events
    try events.register(.Quit, handle_event);
    try events.register(.WindowClose, handle_event);
    try events.register(.WindowResize, handle_event);

    try backend.init();
}

/// shutdown the platform layer
pub fn deinit() void {
    backend.deinit();
}

pub fn handle_event(ev: events.Event) bool {
    switch (ev) {
        .Quit => {
            is_running = false;
            // nobody else really needs this event
            return false;
        },
        .WindowClose => |id| log.info("window {} closed", .{id}),
        .WindowResize => |r| {
            log.debug("event: {}", .{r});
        },
        else => {},
    }

    return true;
}

/// poll for input events on this platform
pub fn flush() void {
    backend.flush();
}

/// get the vulkan instance address
pub fn getInstanceProcAddress() fn (vk.Instance, [*:0]const u8) callconv(.C) vk.PfnVoidFunction {
    //TODO: sanity checks (if it is this function, or empty)
    return vk_get_proc;
}

pub fn createWindowSurface(vki: InstanceDispatch, instance: vk.Instance, window: Window) !vk.SurfaceKHR {
    return backend.createWindowSurface(vki, instance, window);
}

pub fn createWindow(title: []const u8, width: u32, height: u32) anyerror!Window {
    return backend.createWindow(title, width, height);
}

pub fn setWindowTitle(win: Window, title: []const u8) !void {
    return backend.setWindowTitle(win, title);
}

pub fn getWindowSize(win: Window) !Window.Size {
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
