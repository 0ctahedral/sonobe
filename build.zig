const std = @import("std");
const Builder = std.build.Builder;

const glfw = @import("deps/mach-glfw/build.zig");
const vkgen = @import("deps/vulkan-zig/generator/index.zig");
const zigvulkan = @import("deps/vulkan-zig/build.zig");

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

    // temporary executable for the renderer

    // vulkan-zig: Create a step that generates vk.zig (stored in zig-cache) from the provided vulkan registry.
    const gen = vkgen.VkGenerateStep.init(b, "deps/vulkan-zig/examples/vk.xml", "vk.zig");

    const rend_exe = b.addExecutable("renderer", "renderer/main.zig");
    //addOctal(rend_exe);
    rend_exe.addPackage(gen.package);
    rend_exe.addPackagePath("glfw", "deps/mach-glfw/src/main.zig");
    glfw.link(b, rend_exe, .{});
    rend_exe.install();
    rend_exe.addPackage(.{
        .name = "mmath",
        .path = .{ .path = "./math/math.zig" },
    });

    const compile_vert = b.addSystemCommand(&[_][]const u8{
        "glslc",
        "-fshader-stage=vert",
        "assets/builtin.vert.glsl",
        "-o",
        "assets/builtin.vert.spv",
    });

    const compile_frag = b.addSystemCommand(&[_][]const u8{
        "glslc",
        "-fshader-stage=frag",
        "assets/builtin.frag.glsl",
        "-o",
        "assets/builtin.frag.spv",
    });

    rend_exe.step.dependOn(&compile_vert.step);
    rend_exe.step.dependOn(&compile_frag.step);

    const rend_exe_step = b.step("render", "build and run renderer test");
    rend_exe_step.dependOn(&rend_exe.run().step);
}

pub fn addOctal(exe: *std.build.LibExeObjStep) void {
    exe.addPackage(.{
        .name = "octal",
        .path = .{ .path = "./main.zig" },
    });
}
