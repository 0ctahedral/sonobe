const std = @import("std");
const octal = @import("octal");
const cube = @import("cube.zig");
const Renderer = octal.Renderer;
const Resources = Renderer.Resources;

const Handle = Renderer.Handle;
const CmdBuf = Renderer.CmdBuf;
const Mat4 = octal.mmath.Mat4;
const Vec4 = octal.mmath.Vec4;

const Self = @This();

pass: Handle = .{},
pipeline: Handle = .{},
uniform_buffer: Handle = .{},
texture: Handle = .{},
sampler: Handle = .{},
ind_buf: Handle = .{},

const SkyboxData = struct {
    proj: Mat4,
    view: Mat4,
    albedo: Vec4 = Vec4.new(1, 1, 1, 1),
};

pub fn init() !Self {
    var self = Self{};

    // skybox stuff
    // setup the texture
    self.pass = try Resources.createRenderPass(.{
        .clear_color = .{ 0.75, 0.49, 0.89, 1.0 },
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

    self.texture = try Resources.createTexture(.{
        .width = tex_dimension,
        .height = tex_dimension,
        .channels = channels,
        .flags = .{},
        .texture_type = .cubemap,
    }, &pixels);

    self.sampler = try Resources.createSampler(.{
        // .filter = .bilinear,
        .filter = .nearest,
        .repeat = .wrap,
        .compare = .greater,
    });

    self.ind_buf = try Resources.createBuffer(
        .{
            .size = @sizeOf(@TypeOf(cube.indices)),
            .usage = .Index,
        },
    );
    _ = try Renderer.updateBuffer(self.ind_buf, 0, u32, cube.indices[0..]);

    self.uniform_buffer = try Resources.createBuffer(
        .{
            .size = @sizeOf(SkyboxData),
            .usage = .Uniform,
        },
    );
    const group = try Resources.createBindingGroup(&.{
        .{ .binding_type = .Buffer },
        .{ .binding_type = .Texture },
        .{ .binding_type = .Sampler },
    });
    try Resources.updateBindings(group, &[_]Resources.BindingUpdate{
        .{ .binding = 0, .handle = self.uniform_buffer },
        .{ .binding = 1, .handle = self.texture },
        .{ .binding = 2, .handle = self.sampler },
    });

    // // create our shader pipeline
    self.pipeline = try Resources.createPipeline(.{
        .stages = &.{
            .{
                .bindpoint = .Vertex,
                .path = "testbed/assets/skybox.vert.spv",
            },
            .{
                .bindpoint = .Fragment,
                .path = "testbed/assets/skybox.frag.spv",
            },
        },
        .binding_groups = &.{group},
        .renderpass = self.pass,
        .cull_mode = .front,
    });

    return self;
}

pub fn update(self: Self, data: SkyboxData) !void {
    _ = try Renderer.updateBuffer(self.uniform_buffer, 0, SkyboxData, &[_]SkyboxData{data});
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
