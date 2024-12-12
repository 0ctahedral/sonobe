const std = @import("std");
const core = @import("core/core.zig");
pub const log = core.logger.Logger("platform");
// this will eventually be able to do this
// const platform = @import("platform");
const platform = @import("platform/platform.zig");

const Runtime = @import("Runtime.zig");

const posix = std.posix;
const SIG = posix.system.SIG;

pub fn main() !void {
    try platform.init();
    defer platform.deinit();

    const w1 = try platform.createWindow("window 1");
    log.info("created window: {}", .{w1.getWindowID()});
    _ = try platform.createWindow("window 2");

    var runtime = Runtime{};
    try runtime.init();
    defer runtime.deinit();

    try runtime.loop();
}
