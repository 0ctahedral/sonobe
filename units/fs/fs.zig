const builtin = @import("builtin");
pub const Watch = switch (builtin.target.os.tag) {
    .linux => @import("watch_linux.zig"),
    .macos => @import("watch_macos.zig"),
    else => @panic("os not supported"),
};
