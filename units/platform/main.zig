const std = @import("std");
const platform = @import("platform.zig");
const events = @import("events.zig");
const log = @import("utils").log.default;
const Handle = @import("utils").Handle;

var running = std.atomic.Atomic(bool).init(true);

pub fn main() !void {
    events.init();
    defer events.deinit();
    try platform.init(.{});
    defer platform.deinit();
    const wh = try platform.createWindow("window", 800, 800);

    // poll for events every 2.7 ms
    const thread = try std.Thread.spawn(.{}, timedLoop, .{ 16.6, &appLoop, .{} });
    const p_thread = try std.Thread.spawn(.{}, timedLoop, .{ 1000, &printer, .{} });

    try platform.setWindowTitle(wh, "foobar");

    try eventLoop(2.7);

    thread.join();
    p_thread.join();
}

pub fn printer() void {
    log.warn("second", .{});
}

pub fn timedLoop(ms: f32, comptime f: anytype, args: anytype) !void {
    // TODO: assert that f returns a boolean
    const ns_per_update = @floatToInt(i64, ms * std.time.ns_per_ms);
    var tick = try std.time.Instant.now();
    while (running.load(.Acquire)) {
        @call(.auto, f, args);
        // wait the rest of the loop
        var now = try std.time.Instant.now();
        while (ns_per_update - @intCast(i64, now.since(tick)) > 0) {
            now = try std.time.Instant.now();
        }
        tick = try std.time.Instant.now();
    }
}

pub fn appLoop() void {
    platform.startFrame();
    while (events.popEvent()) |ev| {
        switch (ev) {
            .WindowClose => |_| {},
            .MouseButton => {},
            .MouseMove => {},
            .KeyPress, .KeyRelease => {},
            else => {},
        }
    }

    // this is where update would happen
    // instead we quit on cmd q
    {
        if (platform.input.isMod(.{ .super = true }) and platform.input.isKey(.q, .press)) {
            running.store(false, .Release);
        }

        const left = platform.input.getMouse().getButton(.left);
        if (left.action == .drag) {
            // log.debug("{d:.2} {d:.2}", .{ left.drag.x, left.drag.y });
        }
    }

    // reset the mouse
    platform.input.resetMouse();
    platform.input.resetKeyboard();

    // end frame
    platform.endFrame();
}

// high precision pump of event loop at refresh rate
// of ms miliseconds
pub fn eventLoop(ms: f32) !void {
    const ns_per_update = @floatToInt(i64, ms * std.time.ns_per_ms);
    var tick = try std.time.Instant.now();
    while (running.load(.Acquire)) {
        // poll events
        platform.poll();

        // wait the rest of the loop
        var now = try std.time.Instant.now();
        while (ns_per_update - @intCast(i64, now.since(tick)) > 0) {
            now = try std.time.Instant.now();
        }
        tick = try std.time.Instant.now();
    }
}
