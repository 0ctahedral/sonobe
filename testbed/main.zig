//! Entrypoint for an app built with the engine!

const std = @import("std");
// const App = @import("ui_app.zig");
const App = @import("app.zig");
const platform = @import("platform");
const device = @import("device");
const events = platform.events;
const input = platform.input;

var app: App = .{};
var window: platform.Window = .{};
fn onResize(ev: events.Event) bool {
    const rs = ev.WindowResize;
    app.onResize(rs.w, rs.h);
    return true;
}

fn loop() !void {
    while (platform.is_running) {
        platform.startFrame();

        // get events
        platform.flush();
        // want to make sure only the last window resize is used
        events.sendLastType(.WindowResize);
        events.sendAll();

        {
            // update state
            try app.update(platform.dt());
            try app.draw();

            // render frame
            try device.drawFrame();
        }

        // reset the mouse
        input.resetMouse();
        input.resetKeyboard();

        // end frame
        platform.endFrame();
    }
}

pub fn main() !void {
    const allocator = std.testing.allocator;
    // initialize the event system
    events.init();
    defer events.deinit();

    try input.init();
    defer input.deinit();

    // open the window
    try platform.init();
    defer platform.deinit();

    window = try platform.createWindow(App.name, 800, 600);

    //// setup device
    try device.init(allocator, "name", window);
    defer device.deinit();

    try app.init();
    defer app.deinit();

    try events.register(events.EventType.WindowResize, onResize);

    loop() catch |e| {
        std.log.err("got error: {s}", .{@errorName(e)});
        @panic("oops");
    };
}
