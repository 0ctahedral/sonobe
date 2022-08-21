const std = @import("std");
const builtin = @import("builtin");
const Builder = std.build.Builder;

const vkgen = @import("deps/vulkan-zig/generator/index.zig");
const zigvulkan = @import("deps/vulkan-zig/build.zig");
const prefix = @import("src/platform.zig").vkprefix;

const glfw = @import("deps/mach-glfw/build.zig");

pub fn build(b: *Builder) !void {
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    var tests = b.addTest("src/octal.zig");
    tests.setBuildMode(mode);
    tests.setTarget(target);

    const test_step = b.step("test", "Run engine tests");
    test_step.dependOn(&tests.step);

    // make our testbed app
    const exe = try makeApp(b, "testbed", null);
    exe.install();

    const fonts = try makeApp(b, "fonts", "examples/fonts");
    fonts.install();

    const lines = try makeApp(b, "lines", "examples/lines");
    lines.install();

    try compileShadersInDir(b, "assets/shaders/", exe);
    try compileShadersInDir(b, "testbed/assets", exe);
    try compileShadersInDir(b, "examples/fonts/assets", fonts);
    try compileShadersInDir(b, "examples/lines/assets", lines);
}

pub fn makeApp(b: *Builder, name: []const u8, path: ?[]const u8) !*std.build.LibExeObjStep {
    // start with the engine entrypoint
    const exe = b.addExecutable(name, "src/entry.zig");

    linkEngineDeps(b, exe);

    const pkg_path = if (path) |_| b.fmt("{s}/main.zig", .{path}) else b.fmt("{s}/main.zig", .{name});

    // add package for the app contents
    exe.addPackage(.{
        .name = "app",
        .path = .{ .path = pkg_path },
        // depnd on the engine (of course)
        .dependencies = &[_]std.build.Pkg{
            .{
                .name = "octal",
                .path = .{ .path = "./src/octal.zig" },
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

    step.addPackagePath("glfw", "deps/mach-glfw/src/main.zig");
    glfw.link(b, step, .{});

    // TODO: static linking

    // add system dependencies
    step.linkLibC();
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
        .path = .{ .path = "./src/octal.zig" },
        .dependencies = &[_]std.build.Pkg{gen.package},
    });
    // links / c stuff
    step.linkLibC();
    step.addIncludeDir(prefix ++ "/include");

    // add stuff for macos
    switch (builtin.target.os.tag) {
        .macos => {
            // step.addCSourceFile("./src/platform/macos.m", &[_][]const u8{});
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

fn compileShadersInDir(b: *Builder, shader_path: []const u8, step: *std.build.LibExeObjStep) !void {
    var dir = try std.fs.cwd().openDir(shader_path, .{ .iterate = true });
    var iter = dir.iterate();
    while (try iter.next()) |e| {
        if (e.kind == .File) {
            const len = e.name.len;
            if (len <= 10) continue;
            const ext = e.name[(len - 10)..];
            const file_name = e.name[0..(len - 10)];

            var stage: []const u8 = "";

            if (std.mem.eql(u8, ext, ".vert.glsl")) {
                stage = "vert";
            } else if (std.mem.eql(u8, ext, ".frag.glsl")) {
                stage = "frag";
            } else {
                continue;
            }

            var buf1: [256]u8 = undefined;
            var buf2: [256]u8 = undefined;

            var cmd_str = [_][]const u8{
                prefix ++ "/bin/glslc",
                try std.fmt.bufPrint(&buf1, "-fshader-stage={s}", .{stage}),
                try std.fs.path.join(b.allocator, &.{ shader_path, e.name }),
                "-o",
                try std.fmt.bufPrint(&buf2, "{s}/{s}.{s}.spv", .{ shader_path, file_name, stage }),
            };

            const compile_spv = b.addSystemCommand(&cmd_str);

            step.step.dependOn(&compile_spv.step);
        }
    }
}
