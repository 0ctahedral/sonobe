const std = @import("std");
const Runtime = @import("Runtime.zig");

const posix = std.posix;
const SIG = posix.system.SIG;

pub fn main() !void {

    var runtime = Runtime{};

    try runtime.init();
    defer runtime.deinit();

    try runtime.loop();
}
