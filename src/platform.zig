const std = @import("std");
//const glfw = @import("glfw");
const vk = @import("vulkan");
const InstanceDispatch = @import("renderer/dispatch_types.zig").InstanceDispatch;
const Renderer = @import("renderer.zig");
const Events = @import("events.zig");

pub const Window = @import("platform/window.zig");

const backend = @import("platform/linux.zig");

pub var is_running = true;

/// the vulkan dynamic library
var libvk: std.DynLib = undefined;
/// function pointer to vulkan proc
var vk_get_proc: vk.PfnGetInstanceProcAddr = undefined;

pub const vkprefix = backend.vkprefix;

/// Initialize the platform layer
pub fn init() !void {
    libvk = try std.DynLib.open(vkprefix ++ "/lib/libvulkan.so");

    if (libvk.lookup(vk.PfnGetInstanceProcAddr, "vkGetInstanceProcAddr")) |pfn| {
        vk_get_proc = pfn;
    } else {
        return error.CouldNotLoadVulkan;
    }
    return backend.init();
}

/// shutdown the platform layer
pub fn deinit() void {
    backend.deinit();
}

/// poll for input events on this platform
pub fn flush() bool {
    var rev: ?Events.WindowResizeEvent = null;
    while (backend.nextEvent()) |ev| {
        switch (ev) {
            .Quit => is_running = false,
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
        //Renderer.resize(r.w, r.h);
        return false;
    }

    return true;
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
