const std = @import("std");
const builtin = @import("builtin");
const Pkg = std.build.Pkg;

pub fn getPkg(deps: []const Pkg) Pkg {
    return .{
        .name = "mesh",
        .path = .{ .path = thisDir() ++ "/mesh.zig" },
        .dependencies = deps,
    };
}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
