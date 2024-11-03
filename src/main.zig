const std = @import("std");
const core = @import("core/core.zig");
const log = core.logger.Logger("main");

const Runtime = struct {
    const log = core.logger.Logger("runtime");

    const Self = @This();

    // fixed timestep in seconds
    timestep: f32 = 0.01,

    // accumulator for time elapsed between fixed timed steps
    acc: f32 = 0,

    // frame time
    // begin_frame: std.time.Instant,

    pub fn init() !Self {
        return .{
            // .begin_frame = try std.time.Instant.now(),
        };
    }

    pub fn deinit(self: *Self) void {
        // TODO: any cleanup we need
        _ = self;
    }


    /// runs once every fixed timestep (16.6ms)
    pub fn fixedUpdate(self: Self, dt: f32) void {
        _ = self;
        _ = dt;
    }

    /// runs as many times as we can a frame
    pub fn update(self: Self, dt: f32) void {
        _ = self;
        _ = dt;
    }

    fn loop(self: *Self) !void {
        var begin_frame = try std.time.Instant.now();
        while (true) {
            const end_frame = try std.time.Instant.now();

            // delta time for this frame in nanoseconds
            const frame_ns = end_frame.since(begin_frame);
            // convert to seconds
            const frame_s = @as(f32, @floatFromInt(frame_ns)) * 1.0e-9;

            // reset time
            begin_frame = end_frame;

            // update the accumulator
            self.acc += frame_s;

            while (self.acc >= self.timestep) {
                self.fixedUpdate(self.timestep);
                self.acc -= self.timestep;
            }

            // while we still have time since the last frame, run update
            self.update(frame_s);
        }
    }
};

pub fn main() !void {
    log.debug("starting main loop", .{});

    var runtime = try Runtime.init();
    defer runtime.deinit();

    // game loop help from: https://gafferongames.com/post/fix_your_timestep/
    try runtime.loop();

    log.debug("ended main loop", .{});
}
