const std = @import("std");
const builtin = @import("builtin");
const Pkg = std.build.Pkg;

pub const vkprefix = switch (builtin.target.os.tag) {
    .macos => "./deps/vulkan/macos",
    .linux => "./deps/vulkan/x86_64",
    else => unreachable,
};

pub fn getPkg(deps: []const Pkg) Pkg {
    return .{
        .name = "platform",
        .path = .{ .path = thisDir() ++ "/platform.zig" },
        .dependencies = deps,
    };
}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
