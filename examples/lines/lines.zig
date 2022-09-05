const std = @import("std");
const sonobe = @import("sonobe");
const cube = sonobe.mesh.cube;
const quad = sonobe.mesh.quad;
const device = sonobe.device;
const render = sonobe.render;
const Handle = sonobe.Handle;
const CmdBuf = device.CmdBuf;
const resources = sonobe.device.resources;
const math = sonobe.math;
const Vec4 = math.Vec4;
const Vec3 = math.Vec3;
const Vec2 = math.Vec2;
const Quat = math.Quat;
const Mat4 = math.Mat4;

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
index_buf: Handle(null) = .{},
/// data for each line
line_buf: Handle(null) = .{},
/// bind group for our buffers
group: Handle(null) = .{},
/// line renderpass
pass: Handle(null) = .{},
/// pipeline for simple debug type lines
simple_pipeline: Handle(null) = .{},
/// pipeline for more advanced anti aliased lines
aa_pipeline: Handle(null) = .{},
/// wireframe on and culling none
debug_pipeline: Handle(null) = .{},
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

    self.simple_pipeline = try resources.createPipeline(.{
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
    });

    self.aa_pipeline = try resources.createPipeline(.{
        .stages = &.{
            .{
                .bindpoint = .Vertex,
                .path = "examples/lines/assets/lines_aa.vert.spv",
            },
            .{
                .bindpoint = .Fragment,
                .path = "examples/lines/assets/lines_aa.frag.spv",
            },
        },
        .binding_groups = &.{self.group},
        .renderpass = self.pass,
        .cull_mode = .back,
        .push_const_size = @sizeOf(PushConst),
    });

    self.debug_pipeline = try resources.createPipeline(.{
        .stages = &.{
            .{
                .bindpoint = .Vertex,
                .path = "examples/lines/assets/lines_aa.vert.spv",
            },
            .{
                .bindpoint = .Fragment,
                .path = "examples/lines/assets/lines.frag.spv",
            },
        },
        .binding_groups = &.{self.group},
        .renderpass = self.pass,
        .cull_mode = .none,
        .push_const_size = @sizeOf(PushConst),
        .wireframe = true,
    });
    return self;
}

pub fn addLine(self: *Self, data: LineData) !void {
    _ = try device.updateBuffer(
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

    _ = try device.updateBuffer(self.index_buf, @sizeOf(u32) * self.next_index * 6, u32, &[_]u32{
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
            .corner = 1,
            .index = @intCast(u24, self.next_index),
        }),
        @bitCast(u32, Index{
            .corner = 3,
            .index = @intCast(u24, self.next_index),
        }),
        @bitCast(u32, Index{
            .corner = 2,
            .index = @intCast(u24, self.next_index),
        }),
    });

    self.next_index += 1;
}

pub fn clear(self: *Self) void {
    self.next_index = 0;
}

const PushConst = struct {
    view: Mat4,
    proj: Mat4,
    // viewproj: Mat4,
    // aspect: f32,
};

pub const Type = enum {
    debug,
    simple,
    anti_aliased,
};

pub fn draw(self: Self, cmd: *CmdBuf, camera: render.Camera, line_type: Type) !void {
    try cmd.beginRenderPass(self.pass);
    const pipeline = switch (line_type) {
        .debug => self.debug_pipeline,
        .simple => self.simple_pipeline,
        .anti_aliased => self.aa_pipeline,
    };

    try cmd.bindPipeline(pipeline);
    const aspect = 800.0 / 600.0;
    try cmd.pushConst(pipeline, [_]PushConst{.{
        .view = camera.view(),
        .proj = Mat4.ortho(0, aspect, 0, aspect, -100, 100),
    }});

    var i: usize = 0;
    while (i < self.next_index) : (i += 1) {
        // draw the quads
        try cmd.drawIndexed(
            6,
            .{},
            &.{},
            self.index_buf,
            i * 6 * @sizeOf(u32),
        );
    }
    try cmd.endRenderPass(self.pass);
}
