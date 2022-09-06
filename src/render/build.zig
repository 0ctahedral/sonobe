const std = @import("std");
const Pkg = std.build.Pkg;

pub fn getPkg(deps: []const Pkg) Pkg {
    return .{
        .name = "render",
        .path = .{ .path = thisDir() ++ "/render.zig" },
        .dependencies = deps,
    };
}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
