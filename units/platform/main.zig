const std = @import("std");
const platform = @import("macos.zig");
const log = @import("utils").log.default;

const App = struct {
    running: bool = true,
};

pub fn main() !void {
    try platform.init(.{});
    defer platform.deinit();
    try platform.createWindow("window", 800, 800);

    // poll for events every 2.7 ms
    try eventLoop(2.7);
}

// high precision pump of event loop at refresh rate
// of ms miliseconds
pub fn eventLoop(ms: f32) !void {
    const ns_per_update = @floatToInt(i64, ms / std.time.ns_per_ms);
    var tick = try std.time.Instant.now();
    while (true) {
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
