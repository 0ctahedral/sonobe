const std = @import("std");
const platform = @import("macos.zig");
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
    const thread = try std.Thread.spawn(.{}, timedLoop, .{ 16.6, &appLoop, .{wh} });

    try eventLoop(2.7);

    thread.join();
}

pub fn timedLoop(ms: f32, comptime f: anytype, args: anytype) !void {
    // TODO: assert that f returns a boolean
    const ns_per_update = @floatToInt(i64, ms * std.time.ns_per_ms);
    var tick = try std.time.Instant.now();
    while (@call(.auto, f, args)) {
        // wait the rest of the loop
        var now = try std.time.Instant.now();
        while (ns_per_update - @intCast(i64, now.since(tick)) > 0) {
            now = try std.time.Instant.now();
        }
        tick = try std.time.Instant.now();
    }
}

pub fn appLoop(win: Handle(.Window)) bool {
    var i: u32 = 0;
    while (events.popEvent()) |ev| {
        switch (ev) {
            .WindowClose => |wid| {
                if (wid.id == win.id) {
                    running.store(false, .Release);
                }
                return false;
            },
            .MouseButton => |_| {
                i += 1;
            },
            else => {},
        }
    }
    log.debug("{} clicks handled this frame", .{i});
    return true;
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
