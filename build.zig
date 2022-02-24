const std = @import("std");
const Builder = std.build.Builder;

const glfw = @import("deps/mach-glfw/build.zig");
const vkgen = @import("deps/vulkan-zig/generator/index.zig");
const zigvulkan = @import("deps/vulkan-zig/build.zig");
const prefix = @import("src/platform.zig").vkprefix;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    var tests = b.addTest("src/main.zig");
    tests.setBuildMode(mode);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&tests.step);

    const compile_vert = b.addSystemCommand(&[_][]const u8{
        prefix ++ "/bin/glslc",
        "-fshader-stage=vert",
        "assets/builtin.vert.glsl",
        "-o",
        "assets/builtin.vert.spv",
    });

    const compile_frag = b.addSystemCommand(&[_][]const u8{
        prefix ++ "/bin/glslc",
        "-fshader-stage=frag",
        "assets/builtin.frag.glsl",
        "-o",
        "assets/builtin.frag.spv",
    });

    const exe = b.addExecutable("testbed", "testbed/main.zig");
    exe.install();

    const exe_step = b.step("run", "build and run testbed");
    exe_step.dependOn(&exe.run().step);

    //exe.addPackagePath("glfw", "deps/mach-glfw/src/main.zig");
    const gen = vkgen.VkGenerateStep.init(b, "deps/vulkan-zig/examples/vk.xml", "vk.zig");
    exe.addPackage(gen.package);
    exe.addPackage(.{
        .name = "octal",
        .path = .{ .path = "./src/main.zig" },
        .dependencies = &[_]std.build.Pkg{
        //.{
        //    .name = "glfw",
        //    .path = .{ .path = "deps/mach-glfw/src/main.zig" },
        //},
        gen.package},
    });
    // TODO: configure this by os
    exe.linkSystemLibrary("xcb");
    exe.linkSystemLibrary("X11-xcb");

    glfw.link(b, exe, .{});
    exe.addIncludeDir(prefix ++ "/include");

    exe.step.dependOn(&compile_vert.step);
    exe.step.dependOn(&compile_frag.step);
}
