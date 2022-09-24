const std = @import("std");
const device = @import("device");
const utils = @import("utils");
const math = @import("math");
const cube = @import("mesh").cube;

const resources = device.resources;
const descs = device.resources.descs;
const color = utils.color;
const Color = utils.Color;
const Handle = utils.Handle;
const Vec4 = math.Vec4;
const Vec3 = math.Vec3;
const Vec2 = math.Vec2;
const CmdBuf = device.CmdBuf;
const Camera = @import("camera.zig");

const Self = @This();

pass: Handle(.RenderPass) = .{},
pipeline: Handle(.Pipeline) = .{},
uniform_buffer: Handle(.Buffer) = .{},
data: Data = .{},
texture: Handle(.Texture) = .{},
sampler: Handle(.Sampler) = .{},

pub const Data = struct {
    // sky_color: Vec3 = color.hexToVec3(0xbe7ce2),
    sky_color: Vec3 = color.hexToVec3(0x2c0d7a),
    star_density: f32 = 10.0,
    horizon_color: Vec3 = color.hexToVec3(0x8dc2f7),
    star_size: f32 = 0.05,
    sun_dir: Vec3 = Vec3.new(0.0, 0.5, 0.5).norm(),
    sun_size: f32 = 0.3,
};

pub fn init(camera: Camera, procedural: bool, allocator: std.mem.Allocator) !Self {
    var self = Self{};

    // skybox stuff
    // setup the texture
    self.pass = try resources.createRenderPass(.{
        .clear_color = Color{},
        .clear_depth = 1.0,
        .clear_stencil = 1.0,
        .clear_flags = .{ .color = true, .depth = true },
    });

    const tex_dimension: u32 = 2;
    const channels: u32 = 4;
    var pixels: [tex_dimension * tex_dimension * 6 * channels]u8 = .{
        // skybox order: +x, -x, +y, -y, +z, -z
        // red
        255, 0, 0, 255, // 0, 0
        255, 0, 0, 255, // 0, 1
        255, 0, 0, 255, // 1, 0
        255, 0, 0, 255, // 1, 1
        // cyan
        0, 255, 255, 255, // 0, 0
        0, 255, 255, 255, // 0, 1
        0, 255, 255, 255, // 1, 0
        0, 255, 255, 255, // 1, 1
        // green
        0, 255, 0, 255, // 0, 0
        0, 255, 0, 255, // 0, 1
        0, 255, 0, 255, // 1, 0
        0, 255, 0, 255, // 1, 1
        // magenta
        255, 0, 255, 255, // 0, 0
        255, 0, 255, 255, // 0, 1
        255, 0, 255, 255, // 1, 0
        255, 0, 255, 255, // 1, 1
        // blue
        0, 0, 255, 255, // 0, 0
        0, 0, 255, 255, // 0, 1
        0, 0, 255, 255, // 1, 0
        0, 0, 255, 255, // 1, 1
        // yellow
        255, 255, 0, 255, // 0, 0
        255, 255, 0, 255, // 0, 1
        255, 255, 0, 255, // 1, 0
        255, 255, 0, 255, // 1, 1
    };

    self.texture = try resources.createTexture(.{
        .width = tex_dimension,
        .height = tex_dimension,
        .channels = channels,
        .flags = .{},
        .texture_type = .cubemap,
    }, &pixels);

    self.sampler = try resources.createSampler(.{
        .filter = .nearest,
        .repeat = .wrap,
        .compare = .greater,
    });

    self.uniform_buffer = try resources.createBuffer(
        .{
            .size = @sizeOf(Data),
            .usage = .Uniform,
        },
    );
    _ = try resources.updateBufferTyped(self.uniform_buffer, 0, Data, &[_]Data{self.data});

    const group = try resources.createBindGroup(&.{
        .{ .binding_type = .UniformBuffer },
        .{ .binding_type = .Texture },
        .{ .binding_type = .Sampler },
    });
    try resources.updateBindGroup(group, &[_]resources.BindGroupUpdate{
        .{ .binding = 0, .handle = self.uniform_buffer.erased() },
        .{ .binding = 1, .handle = self.texture.erased() },
        .{ .binding = 2, .handle = self.sampler.erased() },
    });

    // create our shader pipeline

    // TODO: make this a specialization constant later
    // or two separate pipelines

    const vert_file = try std.fs.cwd().openFile("assets/shaders/skybox.vert.spv", .{ .read = true });
    defer vert_file.close();

    const frag_path = if (procedural)
        "assets/shaders/procedural_skybox.frag.spv"
    else
        "assets/shaders/skybox.frag.spv";

    const frag_file = try std.fs.cwd().openFile(frag_path, .{ .read = true });
    defer frag_file.close();

    const vert_data = try allocator.alloc(u8, (try vert_file.stat()).size);
    _ = try vert_file.readAll(vert_data);
    defer allocator.free(vert_data);
    const frag_data = try allocator.alloc(u8, (try frag_file.stat()).size);
    _ = try frag_file.readAll(frag_data);
    defer allocator.free(frag_data);

    var pl_desc = descs.PipelineDesc{
        // todo: add camera?
        .renderpass = self.pass,
        .cull_mode = .front,
    };

    pl_desc.bind_groups[0] = group;
    pl_desc.bind_groups[1] = camera.group;

    pl_desc.stages[1] = .{
        .bindpoint = .Fragment,
        .data = frag_data,
    };
    pl_desc.stages[0] = .{
        .bindpoint = .Vertex,
        .data = vert_data,
    };

    self.pipeline = try resources.createPipeline(pl_desc);

    return self;
}

pub fn update(self: Self) !void {
    _ = try resources.updateBufferTyped(self.uniform_buffer, 0, Data, &[_]Data{self.data});
}

pub fn onFileChange(self: *Self, file: *std.fs.File) !void {
    const allocator = std.testing.allocator;

    const slice = try file.readToEndAlloc(allocator, 1024);
    var stream = std.json.TokenStream.init(slice);
    self.data = try std.json.parse(Self.Data, &stream, .{});
    try self.update();
}

pub fn draw(self: Self, cmd: *CmdBuf) !void {
    try cmd.beginRenderPass(self.pass);

    try cmd.bindPipeline(self.pipeline);

    try cmd.drawIndexed(@intCast(u32, cube.indices.len), .{}, &.{}, (try cube.getBuffers()).indices, 0);

    try cmd.endRenderPass(self.pass);
}
