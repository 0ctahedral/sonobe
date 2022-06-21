//! Entrypoint for an app built with the engine!

const std = @import("std");
const App = @import("app");
const Platform = @import("platform.zig");
const Renderer = @import("renderer.zig");
const Events = @import("events.zig");
const Input = @import("input.zig");

// TODO: comptime assert that app has everything we need

pub fn main() !void {
    // initialize the event system
    Events.init();
    defer Events.deinit();

    try Input.init();
    defer Input.deinit();

    // open the window
    try Platform.init();
    defer Platform.deinit();
    errdefer Platform.deinit();

    const window = try Platform.createWindow(App.name, 800, 600);
    _ = window;

    //// setup renderer
    const allocator = std.testing.allocator;
    try Renderer.init(allocator, App.name, window);
    defer Renderer.deinit();

    var app: App = .{};
    try app.init();
    defer app.deinit();

    while (Platform.is_running) {
        Platform.startFrame();

        // get events
        Platform.flush();
        // want to make sure only the last window resize is used
        Events.sendLastType(.WindowResize);
        Events.sendAll();

        {
            // update state
            try app.update(Platform.dt());
            Renderer.backend.push_constant.model = app.t.mat();
            try app.render();

            // render frame
            try Renderer.drawFrame();
        }

        // reset the mouse
        Input.resetMouse();

        // end frame
        Platform.endFrame();
    }
}
