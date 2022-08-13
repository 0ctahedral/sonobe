const std = @import("std");
const octal = @import("octal");
const cube = octal.mesh.cube;
const quad = octal.mesh.quad;
const renderer = octal.renderer;
const Handle = renderer.Handle;
const CmdBuf = renderer.CmdBuf;
const resources = octal.renderer.resources;
const mmath = octal.mmath;
const Vec4 = mmath.Vec4;
const Vec3 = mmath.Vec3;
const Vec2 = mmath.Vec2;
const Quat = mmath.Quat;
const Mat4 = mmath.Mat4;

const Self = @This();
const MAX_LINES = 1024;

/// line positions in world space
pub const LineData = struct {
    /// line start position in world space
    start: Vec3,
    /// line thickness in world space
    thickness: f32 = 1,
    /// line end position in world space
    end: Vec3,
    /// feather amount on line edge
    feather: f32 = 0,
    /// the color of the line
    color: Vec4 = .{ .x = 1, .y = 1, .z = 1, .w = 1 },
};

/// indices for the line quads
index_buf: Handle = .{},
/// data for each line
line_buf: Handle = .{},
/// bind group for our buffers
group: Handle = .{},
/// line renderpass
pass: Handle = .{},
/// pipeline for the line shader
pipeline: Handle = .{},
/// offset into the index buffer
next_index: u32 = 0,

pub fn init() !Self {
    var self = Self{};

    self.pass = try resources.createRenderPass(.{
        .clear_color = Vec4.new(0.0, 0.0, 0.0, 1.0),
        .clear_depth = 1.0,
        .clear_stencil = 1.0,
        // TODO: dont clear color and make the depth shit a setting
        .clear_flags = .{ .depth = true },
    });

    self.index_buf = try resources.createBuffer(
        .{
            .size = MAX_LINES * 6 * @sizeOf(u32),
            .usage = .Index,
        },
    );

    self.group = try resources.createBindingGroup(&.{
        .{ .binding_type = .StorageBuffer },
    });

    self.line_buf = try resources.createBuffer(
        .{
            .size = MAX_LINES * @sizeOf(LineData),
            .usage = .Storage,
        },
    );

    try resources.updateBindings(self.group, &[_]resources.BindingUpdate{
        .{
            .binding = 0,
            .handle = self.line_buf,
        },
    });

    self.pipeline = try resources.createPipeline(.{
        .stages = &.{
            .{
                .bindpoint = .Vertex,
                .path = "examples/lines/assets/lines.vert.spv",
            },
            .{
                .bindpoint = .Fragment,
                .path = "examples/lines/assets/lines.frag.spv",
            },
        },
        .binding_groups = &.{self.group},
        .renderpass = self.pass,
        .cull_mode = .back,
        .push_const_size = @sizeOf(PushConst),
        //.wireframe = true,
    });

    return self;
}

pub fn addLine(self: *Self, data: LineData) !void {
    _ = try renderer.updateBuffer(
        self.line_buf,
        @sizeOf(LineData) * self.next_index,
        LineData,
        &[_]LineData{data},
    );

    // for packing into the indices
    const Index = packed struct {
        index: u24,
        corner: u8,
    };

    _ = try renderer.updateBuffer(self.index_buf, @sizeOf(u32) * self.next_index * 6, u32, &[_]u32{
        @bitCast(u32, Index{
            .corner = 0,
            .index = @intCast(u24, self.next_index),
        }),
        @bitCast(u32, Index{
            .corner = 1,
            .index = @intCast(u24, self.next_index),
        }),
        @bitCast(u32, Index{
            .corner = 2,
            .index = @intCast(u24, self.next_index),
        }),
        @bitCast(u32, Index{
            .corner = 2,
            .index = @intCast(u24, self.next_index),
        }),
        @bitCast(u32, Index{
            .corner = 3,
            .index = @intCast(u24, self.next_index),
        }),
        @bitCast(u32, Index{
            .corner = 0,
            .index = @intCast(u24, self.next_index),
        }),
    });

    self.next_index += 1;
}

pub fn clear(self: *Self) void {
    self.next_index = 0;
}

const PushConst = struct {
    viewproj: Mat4,
    aspect: f32,
};

pub fn draw(self: Self, cmd: *CmdBuf, viewproj: Mat4, aspect: f32) !void {
    try cmd.beginRenderPass(self.pass);
    try cmd.bindPipeline(self.pipeline);
    try cmd.pushConst(self.pipeline, [_]PushConst{.{
        .viewproj = viewproj,
        .aspect = aspect,
    }});
    // draw the quads
    try cmd.drawIndexed(.{
        .count = 6 * self.next_index,
        .vertex_handle = .{},
        .index_handle = self.index_buf,
    });
    try cmd.endRenderPass(self.pass);
}
