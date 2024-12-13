const std = @import("std");
const Compile = std.Build.Step.Compile;

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

    // TODO: put this in a platform module
    exe.linkLibC();
    exe.addLibraryPath(.{ .cwd_relative = "/usr/local/lib/" });
    exe.addIncludePath(.{ .cwd_relative = "/usr/local/include/" });
    exe.linkSystemLibrary("SDL3");

    vulkanSetup(b, exe);

    // install in the zig-out directory
    b.installArtifact(exe);


    // create command and step to run this
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

fn vulkanSetup(b: *std.Build, c: *Compile) void {
    const registry = b.dependency("vulkan_headers", .{}).path("registry/vk.xml");

    const vk_gen = b.dependency("vulkan_zig", .{}).artifact("vulkan-zig-generator");
    const vk_generate_cmd = b.addRunArtifact(vk_gen);
    vk_generate_cmd.addFileArg(registry);


    c.root_module.addAnonymousImport("vulkan", .{
        .root_source_file = vk_generate_cmd.addOutputFileArg("vk.zig"),
    });
}
