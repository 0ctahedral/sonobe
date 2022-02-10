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

    pub const GlobalUniformObject = struct {
        //projection: Mat4 = Mat4.perspective(mmath.util.rad(45), 800.0/600.0, 0.1, 1000),
        projection: Mat4 = Mat4.ortho(0, 800.0, 0, 600.0, -100, 100),
        view: Mat4 = Mat4.identity().inv(),
        // temporary model mat
        model: Mat4 = Mat4.translate(.{.x=400, .y=300, .z=0}),
    };


    const Self = @This();

    // vertex and fragment
    handles: [2]vk.ShaderModule = undefined,
    stage_ci: [2]vk.PipelineShaderStageCreateInfo = undefined,

    // TODO: these might go somewhere else

    global_descriptor_pool: vk.DescriptorPool = undefined,
    
    global_descriptor_sets: [5]vk.DescriptorSet = undefined,

    global_descriptor_layout: vk.DescriptorSetLayout = undefined,

    global_uniform_obj: GlobalUniformObject = .{},

    global_uniform_buffer: Buffer = undefined,

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


        const bindings = [_]vk.DescriptorSetLayoutBinding {
            .{
                .binding = 0,
                .descriptor_type = .uniform_buffer,
                .descriptor_count = 1,
                .stage_flags = .{ .vertex_bit = true },
                .p_immutable_samplers = null,
            }
        };

         self.global_descriptor_layout = try dev.vkd.createDescriptorSetLayout(
             dev.logical,
             &.{
                 .flags = .{},
                 .binding_count = bindings.len,
                 .p_bindings = &bindings,
             }, null);

        const sizes = [_]vk.DescriptorPoolSize{.{
            .@"type" = .uniform_buffer,
            .descriptor_count = self.global_descriptor_sets.len,
        }};

        self.global_descriptor_pool = try dev.vkd.createDescriptorPool(
        dev.logical,
        &.{
            .flags = .{},
            .max_sets =  self.global_descriptor_sets.len,
            .pool_size_count = sizes.len,
            .p_pool_sizes = &sizes,
        }, null);

        // create the buffer
        self.global_uniform_buffer = try Buffer.init(
            dev,
            @sizeOf(GlobalUniformObject),
            .{ .transfer_dst_bit = true, .uniform_buffer_bit = true },
            .{
                .device_local_bit = true,
                .host_visible_bit = true,
                .host_coherent_bit = true,
            },
            true
        );
        
        // allocate the sets
        const layouts = [_]vk.DescriptorSetLayout {
            self.global_descriptor_layout,
            self.global_descriptor_layout,
            self.global_descriptor_layout,
            self.global_descriptor_layout,
            self.global_descriptor_layout,
        };

        try dev.vkd.allocateDescriptorSets(dev.logical, &.{
            .descriptor_pool = self.global_descriptor_pool,
            .descriptor_set_count = self.global_descriptor_sets.len,
            .p_set_layouts = layouts[0..],
        }, self.global_descriptor_sets[0..]);


        return self;
    }


    fn loadShader(name: []const u8, alloctor: std.mem.Allocator) ![]u8 {
        // path for assets
        var buf: [512]u8 = undefined;
        const path = try std.fmt.bufPrint(buf[0..], "assets/{s}.spv", .{name});

        std.log.info("finding file: {s}", .{path});

        const f = try std.fs.cwd().openFile(path, .{ .read = true} );
        defer f.close();

        const ret = try alloctor.alloc(u8, (try f.stat()).size);

        _ = try f.readAll(ret);

        return ret;
    }

    pub fn updateGlobalState(
        self: Self,
        dev: Device,
        cmdbuf: *CommandBuffer,
        pipeline: Pipeline,
        img_idx: usize,
    ) !void {
        dev.vkd.cmdBindDescriptorSets(
            cmdbuf.handle,
            .graphics,
            pipeline.layout,
            0,
            1,
            @ptrCast([*]const vk.DescriptorSet, &self.global_descriptor_sets[img_idx]),
            0,
            undefined,
        );


        try self.global_uniform_buffer.load(
            dev,
            GlobalUniformObject,
            &[_]GlobalUniformObject{
                self.global_uniform_obj
            }, 0);

        const bi = vk.DescriptorBufferInfo {
            .buffer = self.global_uniform_buffer.handle,
            .offset = 0,
            .range = @sizeOf(GlobalUniformObject),
        };

        const writes = [_]vk.WriteDescriptorSet{ .{
            .dst_set = self.global_descriptor_sets[img_idx],
            .dst_binding = 0,
            .dst_array_element = 0,
            .descriptor_count = 1,
            .descriptor_type = .uniform_buffer,
            .p_image_info = undefined,
            .p_buffer_info = @ptrCast([*]const vk.DescriptorBufferInfo, &bi),
            .p_texel_buffer_view = undefined,
        }};

        dev.vkd.updateDescriptorSets(dev.logical, writes.len, &writes, 0, undefined);
    }

    pub fn deinit(
        self: Self,
        dev: Device,
    ) void {

        self.global_uniform_buffer.deinit(dev);

        dev.vkd.destroyDescriptorPool(dev.logical, self.global_descriptor_pool, null);

        dev.vkd.destroyDescriptorSetLayout(dev.logical, self.global_descriptor_layout, null);

        for (self.handles) |h| {
            dev.vkd.destroyShaderModule(dev.logical, h, null);
        }

    }
};
