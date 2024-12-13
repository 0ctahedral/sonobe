const std = @import("std");
const builtin = @import("builtin");
const core = @import("../core/core.zig");
const FreeList = core.containers.FreeList;
pub const log = core.logger.Logger("platform");
pub const Event = @import("event.zig").Event;

const c = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_vulkan.h");
});

const vk = @import("vulkan");

var windows: FreeList(Window) = undefined;
var window_store: [10]Window = undefined;

const app_name = "foobar";
const apis: []const vk.ApiInfo = &.{
    // You can either add invidiual functions by manually creating an 'api'
    .{
        .base_commands = .{
            .createInstance = true,
        },
        .instance_commands = .{
            .createDevice = true,
        },
    },
    // Or you can add entire feature sets or extensions
    vk.features.version_1_0,
    vk.extensions.khr_surface,
    vk.extensions.khr_swapchain,
};

const BaseDispatch = vk.BaseWrapper(apis);
const InstanceDispatch = vk.InstanceWrapper(apis);
const Instance = vk.InstanceProxy(apis);
var vki: InstanceDispatch = undefined;
var instance: Instance = undefined;

pub fn init() !void {
    log.debug("init", .{});

    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
        return error.SDLInitFailed;
    }

    log.debug("SDL3 init success", .{});

    windows = try FreeList(Window).initArena(&window_store);

    log.debug("attempting to init graphics", .{});


    // TODO: move to graphics
    if (!c.SDL_Vulkan_LoadLibrary(null)) {
        return error.CouldNotLoadVulkan;
    }

    // const DeviceDispatch = vk.DeviceWrapper(apis);

    // Also create some proxying wrappers, which also have the respective handles
    // const Device = vk.DeviceProxy(apis);
    const proc_addr: *const fn (instance: vk.Instance, procname: [*:0]const u8) vk.PfnVoidFunction = @ptrCast(c.SDL_Vulkan_GetVkGetInstanceProcAddr());
    var vkb: BaseDispatch = try BaseDispatch.load(proc_addr);

    const required_exts: []const [*:0]const u8 = &[_][*:0]const u8{
        vk.extensions.khr_surface.name,
        vk.extensions.ext_metal_surface.name,
        vk.extensions.khr_portability_enumeration.name,
    };

    log.info("loading extensions:", .{});
    for (required_exts, 0..) |value, i| {
        log.info("extension {}: {s}", .{i, value});
    }

    const app_info = vk.ApplicationInfo{
        .p_application_name = app_name,
        .application_version = vk.makeApiVersion(0, 0, 0, 0),
        .p_engine_name = app_name,
        .engine_version = vk.makeApiVersion(0, 0, 0, 0),
        .api_version = vk.API_VERSION_1_2,
    };

    const layers = &[_][*:0]const u8{
        // vk.extensions.khr_portability_enumeration.name
        // vk.extensions.ext_validation_features.name,
    };

    const vk_instance = try vkb.createInstance(&.{
        .p_application_info = &app_info,
        .enabled_extension_count = required_exts.len,
        .pp_enabled_extension_names = @ptrCast(required_exts),
        .enabled_layer_count = layers.len,
        .pp_enabled_layer_names = @ptrCast(layers),
        .flags = .{.enumerate_portability_bit_khr = true}
    }, null);

    vki = try InstanceDispatch.load(vk_instance, vkb.dispatch.vkGetInstanceProcAddr);
    instance = Instance.init(vk_instance, &vki);
    errdefer instance.destroyInstance(null);
}

pub fn pollEvent() ?Event {
    var event: c.SDL_Event = undefined;
    if (c.SDL_PollEvent(&event)) {
        return blk: {
            break :blk switch (event.type) {
                c.SDL_EVENT_QUIT => .quit,
                c.SDL_EVENT_MOUSE_MOTION => Event{
                    .mouse_move = .{
                        .wid = event.button.windowID,
                        .pos = .{
                            .x = event.motion.x,
                            .y = event.motion.y,
                        },
                        .delta = .{
                            .x = event.motion.xrel,
                            .y = event.motion.yrel,
                        },
                    },
                },
                c.SDL_EVENT_MOUSE_BUTTON_DOWN => Event{
                    .mouse_button = .{
                        .wid = event.button.windowID,
                        .pos = .{
                            .x = event.button.x,
                            .y = event.button.y,
                        },
                        .button = @enumFromInt(event.button.button),
                        .state = .pressed,
                    },
                },
                c.SDL_EVENT_MOUSE_BUTTON_UP => Event{
                    .mouse_button = .{
                        .wid = event.button.windowID,
                        .pos = .{
                            .x = event.button.x,
                            .y = event.button.y,
                        },
                        .button = @enumFromInt(event.button.button),
                        .state = .released,
                    },
                },
                c.SDL_EVENT_WINDOW_CLOSE_REQUESTED => {
                    const closed = .{
                            .wid = event.window.windowID,
                        };
                    var iter = windows.iter();
                    while (iter.next()) |win| {
                        if (closed.wid == win.*.getWindowID()) {
                            win.*.deinit();
                            windows.free(win);
                        }
                    }
                    break :blk  Event{
                        .window_closed = closed,
                    };
                },
                else =>  null,
                // blk: {
                //     log.debug("unhandled event: {d}", .{event.type});
                //     break :blk null;
                // },
            };
        };
    }

    return null;
}

pub fn deinit() void {
    // destroy surface
    var iter = windows.iter();
    while (iter.next()) |win| {
        win.deinit();
    }

    windows.deinit();

    // quit
    c.SDL_Quit();
    log.debug("SDL3 deinit success", .{});
}

pub const Window = packed struct {
    window: *c.SDL_Window,
    surface: vk.SurfaceKHR = .null_handle,

    pub fn init(title: []const u8) !Window {
        log.debug("creating window", .{});
        const flags: u64 = c.SDL_WINDOW_VULKAN;
        var win = Window{
            .window = c.SDL_CreateWindow(@ptrCast(title), 800, 600, flags) orelse return error.CreateWindowFailed,
        };
        log.debug("window: {} created", .{win.window});

        // create surface
        log.debug("creating surface for window {*}", .{win.window});
        
        if (!c.SDL_Vulkan_CreateSurface(win.window, @ptrFromInt(@intFromEnum(instance.handle)), null, @ptrCast(&win.surface))) {
            return error.FailedToCreateSurface;
        }
        return win;
    }

    pub fn deinit(self: *Window) void {
        if (self.surface != .null_handle) {
            log.debug("destroying surface for window {*}", .{self.window});
            instance.destroySurfaceKHR(self.surface, null);
        }
        // destroy window
        log.debug("destroying window {*}", .{self.window});
        c.SDL_DestroyWindow(self.window);
    }

    pub fn getWindowID(self: Window) u32 {
        return c.SDL_GetWindowID(self.window);
    }
};

pub fn createWindow(title: []const u8) !Window {
    var win = try Window.init(title);
    errdefer win.deinit();

    const id: u32 = try windows.allocIndex();
    window_store[id] = win;

    return win;
}
