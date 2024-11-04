const std = @import("std");
const Runtime = @import("Runtime.zig");

const posix = std.posix;
const SIG = posix.system.SIG;

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

    try runtime.loop();
}
