const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    var tests = b.addTest("main.zig");
    tests.setBuildMode(mode);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&tests.step);

    const exe = b.addExecutable("testbed", "testbed/main.zig");
    addOctal(exe);
    exe.install();

    const exe_step = b.step("testbed", "build and run testbed");
    exe_step.dependOn(&exe.run().step);
}

pub fn addOctal(exe: *std.build.LibExeObjStep) void {
    exe.addPackage(.{
        .name = "octal",
        .path = .{ .path = "./main.zig" },
    });
}
