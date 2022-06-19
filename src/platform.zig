const std = @import("std");
const builtin = @import("builtin");
const vk = @import("vulkan");
const InstanceDispatch = @import("renderer/vulkan/dispatch_types.zig").InstanceDispatch;
const Renderer = @import("renderer.zig");
const Events = @import("events.zig");

pub const Window = @import("platform/window.zig");

const backend = switch (builtin.target.os.tag) {
    .macos => @import("platform/macos.zig"),
    .linux => @import("platform/linux.zig"),
    else => unreachable,
};

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
var curr_time: u64 = 0;
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

    try backend.init();
}

/// shutdown the platform layer
pub fn deinit() void {
    backend.deinit();
}

/// poll for input events on this platform
pub fn flush() void {
    var rev: ?Events.WindowResizeEvent = null;
    while (backend.nextEvent()) |ev| {
        switch (ev) {
            .Quit => {
                is_running = false;
            },
            .WindowClose => |id| std.log.info("window {} closed", .{id}),
            .WindowResize => |r| {
                rev = r;
                std.log.debug("event: {}", .{ev});
                //Events.send(ev);
            },
        }
    }
    if (rev) |r| {
        Events.send(Events.Event{ .WindowResize = r });
    }
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

/// the delta time for the current frame
pub inline fn dt() f64 {
    return @intToFloat(f64, delta) / std.time.ns_per_s;
}

/// the fps based on delta time for current frame
pub inline fn fps() f64 {
    return std.time.ns_per_s / @intToFloat(f64, delta);
}
