const std = @import("std");
const builtin = @import("builtin");
const Builder = std.build.Builder;

const vkgen = @import("deps/vulkan-zig/generator/index.zig");
const zigvulkan = @import("deps/vulkan-zig/build.zig");
const glfw = @import("deps/mach-glfw/build.zig");

const math = @import("units/math/build.zig");
const containers = @import("units/containers/build.zig");
const platform = @import("units/platform/build.zig");
const device = @import("units/device/build.zig");
const font = @import("units/font/build.zig");
const mesh = @import("units/mesh/build.zig");
const utils = @import("units/utils/build.zig");
const jobs = @import("units/jobs/build.zig");
const render = @import("units/render/build.zig");
const prefix = platform.vkprefix;

/// all the the available sonobe units, with dependencies sorted out 
pub const units = struct {
    pub const vulkan_pkg = .{
        .name = "vulkan",
        .path = .{ .path = "zig-cache/vk.zig" },
    };
    pub const glfw_pkg = .{
        .name = "glfw",
        .path = .{ .path = "deps/mach-glfw/src/main.zig" },
    };

    pub const containers_pkg = containers.pkg;

    pub const math_pkg = math.pkg;

    pub const utils_pkg = utils.getPkg(&.{
        math_pkg,
    });
    pub const jobs_pkg = jobs.getPkg(&.{
        containers_pkg,
    });
    pub const platform_pkg = platform.getPkg(&.{
        vulkan_pkg,
        glfw_pkg,
        math_pkg,
        containers_pkg,
    });
    pub const device_pkg = device.getPkg(&.{
        vulkan_pkg,
        math_pkg,
        containers_pkg,
        platform_pkg,
        utils_pkg,
    });
    pub const mesh_pkg = mesh.getPkg(&.{
        device_pkg,
        math_pkg,
        utils_pkg,
    });
    pub const font_pkg = font.getPkg(&.{
        device_pkg,
        math_pkg,
        utils_pkg,
        mesh_pkg,
    });
    pub const render_pkg = render.getPkg(&.{
        device_pkg,
        utils_pkg,
        mesh_pkg,
        math_pkg,
    });
};

pub fn build(b: *Builder) !void {
    // const mode = b.standardReleaseOptions();
    // const target = b.standardTargetOptions(.{});

    // make our testbed app
    const exe = try makeApp(b, "testbed", null);
    exe.install();

    // const fonts = try makeApp(b, "fonts", "examples/fonts");
    // fonts.install();

    // const lines = try makeApp(b, "lines", "examples/lines");
    // lines.install();

    try compileShadersInDir(b, "assets/shaders/", exe);
    try compileShadersInDir(b, "testbed/assets", exe);
    // try compileShadersInDir(b, "examples/lines/assets", lines);
}

pub fn makeApp(b: *Builder, name: []const u8, path: ?[]const u8) !*std.build.LibExeObjStep {
    _ = path;
    const app_path = if (path) |_| b.fmt("{s}/main.zig", .{path}) else b.fmt("{s}/main.zig", .{name});
    // start with the engine entrypoint
    const exe = b.addExecutable(name, app_path);

    _ = vkgen.VkGenerateStep.init(b, "deps/vulkan-zig/examples/vk.xml", "vk.zig");

    exe.addPackage(units.containers_pkg);
    exe.addPackage(units.font_pkg);
    exe.addPackage(units.jobs_pkg);
    exe.addPackage(units.mesh_pkg);
    exe.addPackage(units.utils_pkg);
    exe.addPackage(units.render_pkg);
    exe.addPackage(units.math_pkg);
    exe.addPackage(units.platform_pkg);
    exe.addPackage(units.glfw_pkg);
    exe.addPackage(units.device_pkg);
    glfw.link(b, exe, .{});

    // TODO: static linking

    // add system dependencies
    exe.linkLibC();
    const lib_names = [_][]const u8{
        "xcb",
        "X11-xcb",
    };
    for (lib_names) |ln| {
        exe.linkSystemLibrary(ln);
    }

    const exe_step = b.step(b.fmt("run_{s}", .{name}), b.fmt("build and run {s}", .{name}));
    exe_step.dependOn(&exe.run().step);

    return exe;
}

/// add this library package to the executable
/// and link dependencies
fn link(b: *Builder, step: *std.build.LibExeObjStep) void {
    _ = b;
    // packages
    const gen = vkgen.VkGenerateStep.init(b, "deps/vulkan-zig/examples/vk.xml", "vk.zig");
    step.addPackage(.{
        .name = "sonobe",
        .path = .{ .path = "./units/sonobe.zig" },
        .dependencies = &[_]std.build.Pkg{gen.package},
    });
    // links / c stuff
    step.linkLibC();
    step.addIncludeDir(prefix ++ "/include");

    // add stuff for macos
    switch (builtin.target.os.tag) {
        .macos => {
            // step.addCSourceFile("./units/platform/macos.m", &[_][]const u8{});
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
