const std = @import("std");

pub fn build(b: *std.Build) void {
    // set the target and optimization
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // create executable
    const exe = b.addExecutable(.{
        .name = "sonobe",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.linkLibC();
    exe.addLibraryPath(.{ .cwd_relative = "/usr/local/lib/" });
    exe.addIncludePath(.{ .cwd_relative = "/usr/local/include/" });
    exe.linkSystemLibrary("SDL3");

    // install in the zig-out directory
    b.installArtifact(exe);


    // create command and step to run this
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
