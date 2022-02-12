//! shader type and stuff
const std = @import("std");
const vk = @import("vulkan");
const Device = @import("device.zig").Device;
const Buffer = @import("buffer.zig").Buffer;
const CommandBuffer = @import("commandbuffer.zig").CommandBuffer;
const Pipeline = @import("pipeline.zig").Pipeline;
const mmath = @import("mmath");
const Mat4 = mmath.Mat4;
const Vec3 = mmath.Vec3;

const BUILTIN_SHADER_NAME_OBJ = "builtin";

/// TODO: this might need to be more of an interface
pub const Shader = struct {

    const Self = @This();

    // vertex and fragment
    handles: [2]vk.ShaderModule = undefined,
    stage_ci: [2]vk.PipelineShaderStageCreateInfo = undefined,

    pub fn init(
        dev: Device,
        allocator: std.mem.Allocator,
    ) !Self {

        var self = Self{};

        const stage_types = [_]vk.ShaderStageFlags{
            .{ .vertex_bit = true },
            .{ .fragment_bit = true },
        };

        const stage_names = [_][]const u8{
            "builtin.vert",
            "builtin.frag",
        };

        // create a shader module for each stage
        for (self.handles) |*h, i| {
            const data = try loadShader(stage_names[i], allocator);

            h.* = try dev.vkd.createShaderModule(dev.logical, &.{
                .flags = .{},
                .code_size = data.len,
                .p_code = @ptrCast([*]const u32, @alignCast(4, data)),
            }, null);

            self.stage_ci[i] = vk.PipelineShaderStageCreateInfo{
                .flags = .{},
                .stage = stage_types[i],
                .module = h.*,
                .p_name = "main",
                .p_specialization_info = null,
            };

            allocator.free(data);
        }


        return self;
    }


    fn loadShader(name: []const u8, alloctor: std.mem.Allocator) ![]u8 {
        // path for assets
        var buf: [512]u8 = undefined;
        //const path = try std.fmt.bufPrint(buf[0..], "assets/{s}.spv", .{name});
        const path = try std.fmt.bufPrint(buf[0..], "/home/oct/code/octal/assets/{s}.spv", .{name});


        std.log.info("finding file: {s}", .{path});

        //const f = try std.fs.cwd().openFile(path, .{ .read = true} );
        const f = try std.fs.openFileAbsolute(path, .{ .read = true} );
        defer f.close();

        const ret = try alloctor.alloc(u8, (try f.stat()).size);

        _ = try f.readAll(ret);

        return ret;
    }


    pub fn deinit(
        self: Self,
        dev: Device,
    ) void {

        for (self.handles) |h| {
            dev.vkd.destroyShaderModule(dev.logical, h, null);
        }

    }
};
