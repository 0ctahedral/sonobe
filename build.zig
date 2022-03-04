const std = @import("std");
const Builder = std.build.Builder;

const vkgen = @import("deps/vulkan-zig/generator/index.zig");
const zigvulkan = @import("deps/vulkan-zig/build.zig");
const prefix = @import("src/platform.zig").vkprefix;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    var tests = b.addTest("src/main.zig");
    tests.setBuildMode(mode);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&tests.step);

    const exe = b.addExecutable("testbed", "testbed/main.zig");
    exe.install();

    const exe_step = b.step("run", "build and run testbed");
    exe_step.dependOn(&exe.run().step);

    link(b, exe);

    compileBuiltinShaders(b, exe);
}

/// add this library package to the executable
/// and link dependencies
fn link(b: *Builder, step: *std.build.LibExeObjStep) void {
    // packages
    const gen = vkgen.VkGenerateStep.init(b, prefix ++ "/vk.xml", "vk.zig");
    step.addPackage(.{
        .name = "octal",
        .path = .{ .path = "./src/main.zig" },
        .dependencies = &[_]std.build.Pkg{gen.package},
    });
    // links / c stuff
    step.linkLibC();
    step.addIncludeDir(prefix ++ "/include");
    // TODO: configure this by os
    const lib_names = [_][]const u8{
        "xcb",
        "X11-xcb",
    };
    for (lib_names) |ln| {
        step.linkSystemLibrary(ln);
    }
}

// TODO: make this compile all shaders in the folder
fn compileBuiltinShaders(b: *Builder, step: *std.build.LibExeObjStep) void {
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

    step.step.dependOn(&compile_vert.step);
    step.step.dependOn(&compile_frag.step);
}
