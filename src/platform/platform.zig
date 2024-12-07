const builtin = @import("builtin");
const core = @import("../core/core.zig");
pub const log = core.logger.Logger("platform");
pub const Event = @import("event.zig").Event;

const c = @cImport(
    @cInclude("SDL3/SDL.h")
);

var window: ?*c.SDL_Window = null;
var surface: ?*c.SDL_Surface = null;

pub fn init() !void {
    log.debug("init", .{});

    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
        return error.SDLInitFailed;
    }

    log.debug("SDL3 init success", .{});

    // create window
    window = c.SDL_CreateWindow("sdl3 test", 800, 600, 0);
    if (window == null) {
        return error.SDLNoWindow;
    }

    // create surface
    surface = c.SDL_GetWindowSurface(window);
}

pub fn pollEvent() ?Event {
    var event: c.SDL_Event = undefined;
    if (c.SDL_PollEvent(&event)) {
        return switch (event.type) {
            c.SDL_EVENT_QUIT => .quit,
            c.SDL_EVENT_MOUSE_MOTION => Event{
                .mouse_move = .{
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
            else => blk: {
                log.debug("unhandled event: {d}", .{event.type});
                break :blk null;
            },
        };
    }

    return null;
}

pub fn deinit() void {
    // destroy surface
    c.SDL_DestroySurface(surface);
    // destroy window
    c.SDL_DestroyWindow(window);

    // quit
    c.SDL_Quit();
    log.debug("SDL3 deinit success", .{});
}
