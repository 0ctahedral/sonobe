const std = @import("std");
const builtin = @import("builtin");
const Builder = std.build.Builder;
pub const units = @import("units/units.zig");

const glfw = @import("deps/mach-glfw/build.zig");
// TODO: get rid of this
const prefix = @import("units/platform/build.zig").vkprefix;

pub fn build(b: *Builder) !void {
    // build all the projects
    const testbed = @import("testbed/build.zig");
    try testbed.build(b);

    const test_step = b.step("test", "run fs tests");

    // const fs_tests = b.addTest("units/fs/test.zig");
    // fs_tests.addPackage(units.fs);
    // fs_tests.addPackage(units.utils);
    // test_step.dependOn(&fs_tests.step);

    const utils_tests = b.addTest("testbed/imgui/tree.zig");
    for (units.utils.dependencies.?) |d| {
        utils_tests.addPackage(d);
    }
    test_step.dependOn(&utils_tests.step);
}

pub fn linkDeps(b: *Builder, exe: *std.build.LibExeObjStep) !void {
    glfw.link(b, exe, .{});
    try compileShadersInDir(b, "assets/shaders/", exe);
}

/// compile all shaders in a given directory 
pub fn compileShadersInDir(b: *Builder, shader_path: []const u8, exe: *std.build.LibExeObjStep) !void {
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

            exe.step.dependOn(&compile_spv.step);
        }
    }
}
