const std = @import("std");

pub const pkg: std.build.Pkg = .{
    .name = "math",
    .path = .{ .path = thisDir() ++ "/math.zig" },
};

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
