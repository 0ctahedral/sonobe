const std = @import("std");
const builtin = @import("builtin");
const Builder = std.build.Builder;
pub const units = @import("units/units.zig");

const glfw = @import("deps/mach-glfw/build.zig");
// TODO: these aren't currently used since we already have the
// generated files
// might want to just add generated files as dependency and use generator as separate tool
const vkgen = @import("deps/vulkan-zig/generator/index.zig");
const zigvulkan = @import("deps/vulkan-zig/build.zig");
// TODO: get rid of this
const prefix = @import("units/platform/build.zig").vkprefix;

pub fn build(b: *Builder) !void {
    // build all the projects
    const testbed = @import("testbed/build.zig");
    try testbed.build(b);
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
