const std = @import("std");
const builtin = @import("builtin");
const vk = @import("vulkan");
const InstanceDispatch = @import("renderer/vulkan/dispatch_types.zig").InstanceDispatch;
pub const events = @import("platform/events.zig");
pub const input = @import("platform/input.zig");

pub const Window = @import("platform/window.zig");

const backend = @import("platform/glfw.zig");

pub var is_running = true;

/// the vulkan dynamic library
var libvk: std.DynLib = undefined;
/// function pointer to vulkan proc
var vk_get_proc: vk.PfnGetInstanceProcAddr = undefined;

pub const vkprefix = switch (builtin.target.os.tag) {
    .macos => "./deps/vulkan/macos",
    .linux => "./deps/vulkan/x86_64",
    else => unreachable,
};

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

var timer: std.time.Timer = undefined;
pub var curr_time: u64 = 0;
var delta: u64 = 0;

/// Initialize the platform layer
pub fn init() !void {
    libvk = try std.DynLib.open(vkdl);

    if (libvk.lookup(vk.PfnGetInstanceProcAddr, "vkGetInstanceProcAddr")) |pfn| {
        vk_get_proc = pfn;
    } else {
        return error.CouldNotLoadVulkan;
    }

    // start the timer
    timer = try std.time.Timer.start();

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
        .WindowClose => |id| std.log.info("window {} closed", .{id}),
        .WindowResize => |r| {
            std.log.debug("event: {}", .{r});
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
    curr_time = timer.read();
}

/// ends a frame: used for tracking delta time and stuff
pub fn endFrame() void {
    const new_time = timer.read();
    delta = new_time - curr_time;
    curr_time = new_time;
}

/// the delta time for the current frame in seconds
pub inline fn dt() f64 {
    return @intToFloat(f64, delta) / std.time.ns_per_s;
}

/// the fps based on delta time for current frame
pub inline fn fps() f64 {
    return std.time.ns_per_s / @intToFloat(f64, delta);
}
