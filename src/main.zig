const std = @import("std");
const core = @import("core/core.zig");

const posix = std.posix;
const SIG = posix.system.SIG;

const Runtime = struct {
    const log = core.logger.Logger("runtime");

    const Self = @This();

    // fixed timestep in seconds
    fixed_step_s: f32 = 0.01,

    // accumulator for time elapsed between fixed time steps
    frame_acc_s: f32 = 0,

    // total time ellapsed since starting
    ellapsed_ns: u64 = 0,

    is_running: std.Thread.ResetEvent = .{},

    pub fn init(self: *Self) !void {
        log.debug("init runtime", .{});
        self.ellapsed_ns = 0;
        self.is_running.set();
    }

    pub fn deinit(self: *Self) void {
        log.debug("deinit runtime", .{});
        // TODO: any cleanup we need
        _ = self;
    }

    /// total time the runtime has been running, in seconds
    fn time(self: Self) f32 {
        return @as(f32, @floatFromInt(self.ellapsed_ns)) * 1e-9;
    }

    /// runs once every fixed timestep
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
        while (self.is_running.isSet()) {
            const end_frame = try std.time.Instant.now();

            // delta time for this frame in nanoseconds
            const frame_ns = end_frame.since(begin_frame);
            self.ellapsed_ns += frame_ns;

            // convert to seconds
            const frame_s = @as(f32, @floatFromInt(frame_ns)) * 1.0e-9;

            // reset time
            begin_frame = end_frame;

            // update the accumulator
            self.frame_acc_s += frame_s;

            while (self.frame_acc_s >= self.fixed_step_s) {
                self.fixedUpdate(self.fixed_step_s);
                self.frame_acc_s -= self.fixed_step_s;
            }

            // while we still have time since the last frame, run update
            self.update(frame_s);
        }
    }
};


var running_event: ?*std.Thread.ResetEvent = null;

fn handle_sig(sig: c_int) callconv(.C) void {
    _ = sig;
    if (running_event != null) {
        running_event.?.reset();
    }
}

pub fn main() !void {

    var runtime = Runtime{};
    running_event = &runtime.is_running;

    const sigact = posix.Sigaction{
        .handler = .{ .handler = handle_sig },
        .mask = posix.empty_sigset,
        .flags = 0,
    };
    // setup signal handlers
    try std.posix.sigaction(SIG.INT, &sigact, null);

    try runtime.init();
    defer runtime.deinit();

    // game loop help from: https://gafferongames.com/post/fix_your_timestep/
    try runtime.loop();
}
