//! Entrypoint for an app built with the engine!

const std = @import("std");
const App = @import("app");
const Platform = @import("platform.zig");
const Renderer = @import("renderer.zig");
const Events = @import("events.zig");
const Input = @import("input.zig");

var app: App = .{};
var window: Platform.Window = .{};
fn onResize(ev: Events.Event) bool {
    const rs = ev.WindowResize;
    app.onResize(rs.w, rs.h);
    return true;
}

fn loop() !void {
    var last_fps_time: u64 = 0;
    var buf: [80]u8 = undefined;

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
            try app.render();

            // render frame
            try Renderer.drawFrame();
        }

        // reset the mouse
        Input.resetMouse();
        Input.resetKeyboard();

        if ((Platform.curr_time - last_fps_time) > std.time.ns_per_s) {
            last_fps_time = Platform.curr_time;
            try Platform.setWindowTitle(window, try std.fmt.bufPrint(buf[0..], "testbed fps: {d:.2}\x00", .{Platform.fps()}));
        }
        // end frame
        Platform.endFrame();
    }
}

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

    window = try Platform.createWindow(App.name, 1920, 1080);

    //// setup renderer
    const allocator = std.testing.allocator;
    try Renderer.init(allocator, App.name, window);
    defer Renderer.deinit();

    try app.init();
    defer app.deinit();

    if (@hasDecl(App, "onResize")) {
        std.log.info("app has resize", .{});
        try Events.register(Events.EventType.WindowResize, onResize);
    }

    try loop();
}
