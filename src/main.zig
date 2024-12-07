const std = @import("std");
// this will eventually be able to do this
// const platform = @import("platform");
const platform = @import("platform/platform.zig");

const Runtime = @import("Runtime.zig");

const posix = std.posix;
const SIG = posix.system.SIG;

pub fn main() !void {
    try platform.init();
    defer platform.deinit();

    var runtime = Runtime{};
    try runtime.init();
    defer runtime.deinit();

    try runtime.loop();
}
