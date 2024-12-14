const std = @import("std");
const builtin = @import("builtin");
const vk = @import("vulkan");
const core = @import("core.zig");
const FreeList = core.containers.FreeList;
pub const Event = @import("platform/event.zig").Event;
pub const gpu = @import("platform/gpu.zig");

pub const log = core.logger.Logger("platform");

const c = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_vulkan.h");
});


var windows: FreeList(Window) = undefined;
var window_store: [10]Window = undefined;

pub fn init() !void {
    log.info("init", .{});

    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
        return error.SDLInitFailed;
    }

    log.info("SDL3 init success", .{});

    windows = try FreeList(Window).initArena(&window_store);
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
    log.info("SDL3 deinit success", .{});
}

pub const Window = struct {
    window: *c.SDL_Window,
    surface: ?gpu.Surface = null,

    pub fn init(title: []const u8) !Window {
        log.info("creating window", .{});
        const flags: u64 = c.SDL_WINDOW_VULKAN;
        const win_ptr = try windows.alloc();
        errdefer windows.free(win_ptr);

        win_ptr.* = Window{
            .window = c.SDL_CreateWindow(@ptrCast(title), 800, 600, flags) orelse return error.CreateWindowFailed,
        };

        log.info("window: {} created", .{win_ptr.window});
        return win_ptr.*;
    }

    pub fn getTitle(self: Window) [*:0]const u8 {
        return c.SDL_GetWindowTitle(self.window);
    }

    pub fn deinit(self: *Window) void {
        if (self.surface) |*s| {
            s.deinit();
        }
        // destroy window
        log.info("destroying window {*}", .{self.window});
        c.SDL_DestroyWindow(self.window);
    }

    pub fn getWindowID(self: Window) u32 {
        return c.SDL_GetWindowID(self.window);
    }
};
