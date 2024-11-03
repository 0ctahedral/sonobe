const std = @import("std");
const core = @import("core/core.zig");
const log = core.logger.default;

pub fn main() !void {
    log.debug("sonobe!", .{});
}
