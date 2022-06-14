const std = @import("std");
const builtin = @import("builtin");
const Builder = std.build.Builder;

const vkgen = @import("deps/vulkan-zig/generator/index.zig");
const zigvulkan = @import("deps/vulkan-zig/build.zig");
const prefix = @import("src/platform.zig").vkprefix;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    var tests = b.addTest("src/main.zig");
    tests.setBuildMode(mode);

    const test_step = b.step("test", "Run engine tests");
    test_step.dependOn(&tests.step);

    // make our testbed app
    const exe = try makeApp(b, "testbed");
    exe.install();

    compileBuiltinShaders(b, exe);
}

pub fn makeApp(b: *Builder, name: []const u8) !*std.build.LibExeObjStep {
    // start with the engine entrypoint
    const exe = b.addExecutable(name, "src/entry.zig");

    linkEngineDeps(b, exe);

    // add package for the app contents
    exe.addPackage(.{
        .name = "app",
        .path = .{ .path = b.fmt("{s}/main.zig", .{name}) },
        // depnd on the engine (of course)
        .dependencies = &[_]std.build.Pkg{
            .{
                .name = "octal",
                .path = .{ .path = "./src/main.zig" },
            },
        },
    });

    const exe_step = b.step(b.fmt("run_{s}", .{name}), b.fmt("build and run {s}", .{name}));
    exe_step.dependOn(&exe.run().step);

    return exe;
}

fn linkEngineDeps(b: *Builder, step: *std.build.LibExeObjStep) void {
    // add vulkan
    const gen = vkgen.VkGenerateStep.init(b, "deps/vulkan-zig/examples/vk.xml", "vk.zig");
    step.addPackage(gen.package);

    // TOOD: static linking

    // add system dependencies
    step.linkLibC();
    switch (builtin.target.os.tag) {
        .macos => {
            step.addCSourceFile("./src/platform/macos.m", &[_][]const u8{});
            step.linkFramework("AppKit");
            step.linkFramework("QuartzCore");
        },
        else => {},
    }

    // TODO: configure this by os
    const lib_names = [_][]const u8{
        "xcb",
        "X11-xcb",
    };
    for (lib_names) |ln| {
        step.linkSystemLibrary(ln);
    }
}

/// add this library package to the executable
/// and link dependencies
fn link(b: *Builder, step: *std.build.LibExeObjStep) void {
    _ = b;
    // packages
    const gen = vkgen.VkGenerateStep.init(b, "deps/vulkan-zig/examples/vk.xml", "vk.zig");
    step.addPackage(.{
        .name = "octal",
        .path = .{ .path = "./src/main.zig" },
        .dependencies = &[_]std.build.Pkg{gen.package},
    });
    // links / c stuff
    step.linkLibC();
    step.addIncludeDir(prefix ++ "/include");

    // add stuff for macos
    switch (builtin.target.os.tag) {
        .macos => {
            step.addCSourceFile("./src/platform/macos.m", &[_][]const u8{});
            step.linkFramework("AppKit");
            step.linkFramework("QuartzCore");
        },
        else => {},
    }

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
    const shader_names = [_][]const u8{
        "assets/builtin",
        // "assets/test",
    };

    inline for (shader_names) |name| {
        const compile_vert = b.addSystemCommand(&[_][]const u8{
            prefix ++ "/bin/glslc",
            "-fshader-stage=vert",
            name ++ ".vert.hlsl",
            "-o",
            name ++ ".vert.spv",
        });

        const compile_frag = b.addSystemCommand(&[_][]const u8{
            prefix ++ "/bin/glslc",
            "-fshader-stage=frag",
            name ++ ".frag.hlsl",
            "-o",
            name ++ ".frag.spv",
        });

        step.step.dependOn(&compile_vert.step);
        step.step.dependOn(&compile_frag.step);
    }
}
