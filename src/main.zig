const std = @import("std");
const core = @import("core/core.zig");
const log = core.logger.Logger("main");

/// runs once every fixed timestep (16.6ms)
pub fn fixedUpdate(dt: f32) void {
    _ = dt;
}

/// runs as many times as we can a frame
pub fn update(dt: f32) void {
    _ = dt;
}

pub fn main() !void {
    log.debug("starting main loop", .{});

    // timestep in seconds
    const timestep: f32 = 0.5;

    // accumulator for time elapsed in this frame
    var acc: f32 = 0;

    // frame time
    var begin_frame = try std.time.Instant.now();

    // game loop help from: https://gafferongames.com/post/fix_your_timestep/
    while (true) {
        const end_frame = try std.time.Instant.now();

        // delta time for this frame in nanoseconds
        const frame_ns = end_frame.since(begin_frame);
        // convert to seconds
        const frame_s = @as(f32, @floatFromInt(frame_ns)) * 1.0e-9;

        // reset time
        begin_frame = end_frame;

        // update the accumulator
        acc += frame_s;

        while (acc >= timestep) {
            fixedUpdate(timestep);
            acc -= timestep;
        }

        // TODO: here is where input will happen

        // while we still have time since the last frame, run update
        update(frame_s);
    }

    log.debug("ended main loop", .{});
}
