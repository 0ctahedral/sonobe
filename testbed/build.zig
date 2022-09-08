const std = @import("std");
const Builder = std.build.Builder;
const sonobe = @import("../build.zig");

pub fn build(b: *Builder) !void {
    const exe = b.addExecutable("testbed", thisDir() ++ "main.zig");
    try sonobe.linkDeps(b, exe);
    try sonobe.compileShadersInDir(b, thisDir() ++ "assets/", exe);

    // TODO: maybe make a function that takes all the package names?
    exe.addPackage(sonobe.units.math);
    exe.addPackage(sonobe.units.platform);
    exe.addPackage(sonobe.units.device);
    exe.addPackage(sonobe.units.utils);
    exe.addPackage(sonobe.units.mesh);
    exe.addPackage(sonobe.units.render);

    exe.install();

    const exe_step = b.step("run", "run the testbed");
    exe_step.dependOn(&exe.run().step);
}

inline fn thisDir() []const u8 {
    return comptime (std.fs.path.dirname(@src().file) orelse ".") ++ "/";
}
