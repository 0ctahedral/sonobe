const std = @import("std");
const octal = @import("octal");
const cube = octal.mesh.cube;
const renderer = octal.renderer;
const resources = renderer.resources;

const Handle = renderer.Handle;
const CmdBuf = renderer.CmdBuf;
const Mat4 = octal.mmath.Mat4;
const Vec3 = octal.mmath.Vec3;
const Camera = @import("camera.zig");

const Self = @This();

pass: Handle = .{},
pipeline: Handle = .{},
uniform_buffer: Handle = .{},
data: Data = .{},
texture: Handle = .{},
sampler: Handle = .{},
ind_buf: Handle = .{},

pub const Data = struct {
    // sky_color: Vec3 = octal.color.hexToVec3(0xbe7ce2),
    sky_color: Vec3 = octal.color.hexToVec3(0x2c0d7a),
    star_density: f32 = 10.0,
    horizon_color: Vec3 = octal.color.hexToVec3(0x8dc2f7),
    star_size: f32 = 0.05,
    sun_dir: Vec3 = Vec3.new(0.0, 0.5, 0.5).norm(),
    sun_size: f32 = 0.3,
};

pub fn init(camera: Camera, procedural: bool) !Self {
    var self = Self{};

    // skybox stuff
    // setup the texture
    self.pass = try resources.createRenderPass(.{
        // .clear_color = .{ 0.75, 0.49, 0.89, 1.0 },
        .clear_color = .{ 0.0, 0.0, 0.0, 1.0 },
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

    self.ind_buf = try resources.createBuffer(
        .{
            .size = cube.indices.len * @sizeOf(u32),
            .usage = .Index,
        },
    );
    _ = try renderer.updateBuffer(self.ind_buf, 0, u32, cube.indices);

    self.uniform_buffer = try resources.createBuffer(
        .{
            .size = @sizeOf(Data),
            .usage = .Uniform,
        },
    );
    _ = try renderer.updateBuffer(self.uniform_buffer, 0, Data, &[_]Data{self.data});

    const group = try resources.createBindingGroup(&.{
        .{ .binding_type = .Buffer },
        .{ .binding_type = .Texture },
        .{ .binding_type = .Sampler },
    });
    try resources.updateBindings(group, &[_]resources.BindingUpdate{
        .{ .binding = 0, .handle = self.uniform_buffer },
        .{ .binding = 1, .handle = self.texture },
        .{ .binding = 2, .handle = self.sampler },
    });

    // create our shader pipeline

    // TODO: make this a specialization constant later
    // or two separate pipelines
    const frag_stage: renderer.types.StageDesc =
        if (procedural)
    .{
        .bindpoint = .Fragment,
        .path = "testbed/assets/procedural_skybox.frag.spv",
    } else .{
        .bindpoint = .Fragment,
        .path = "testbed/assets/skybox.frag.spv",
    };

    const stages = .{
        .{
            .bindpoint = .Vertex,
            .path = "testbed/assets/skybox.vert.spv",
        },
        frag_stage,
    };

    self.pipeline = try resources.createPipeline(.{
        .stages = &stages,
        // todo: add camera?
        .binding_groups = &.{ group, camera.group },
        .renderpass = self.pass,
        .cull_mode = .front,
    });

    return self;
}

pub fn update(self: Self) !void {
    _ = try renderer.updateBuffer(self.uniform_buffer, 0, Data, &[_]Data{self.data});
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

    try cmd.drawIndexed(.{
        .count = cube.indices.len,
        .vertex_handle = .{},
        .index_handle = self.ind_buf,
    });

    try cmd.endRenderPass(self.pass);
}
