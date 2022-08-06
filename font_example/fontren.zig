const std = @import("std");
const octal = @import("octal");
const renderer = octal.renderer;
const resources = octal.renderer.resources;
const font = octal.font;
const quad = octal.mesh.quad;
const mmath = octal.mmath;

const Allocator = std.mem.Allocator;

const CmdBuf = renderer.CmdBuf;
const Vec2 = mmath.Vec2;
const Vec3 = mmath.Vec3;
const Vec4 = mmath.Vec4;
const Mat4 = mmath.Mat4;

const Self = @This();

const GlyphData = struct {
    rect: Vec4,
    bb: Vec4,
};

const MAX_GLYPHS = 1024;

allocator: Allocator,

bdf: font.BDF,
/// bindgroup for the font
group: renderer.Handle = .{},
/// buffer containing the orthographic matrix?
/// later it will contain the offsets of the glyphs
buffer: renderer.Handle = .{},
/// quad for fonts
inds: renderer.Handle = .{},
/// texture containing all the glyphs
texture: renderer.Handle = .{},
/// sampler for above texture
sampler: renderer.Handle = .{},
/// pipeline for rendering fonts
pipeline: renderer.Handle = .{},
/// pipeline for rendering fonts
atlas_pipeline: renderer.Handle = .{},

// offset into the index buffer
index_offset: u32 = 0,

pub fn init(path: []const u8, renderpass: renderer.Handle, allocator: Allocator) !Self {
    var self = Self{
        .allocator = allocator,
        .bdf = try font.loadBDF(path, allocator),
    };

    self.inds = try resources.createBuffer(
        .{
            .size = MAX_GLYPHS * @sizeOf(u32),
            .usage = .Index,
        },
    );

    self.group = try resources.createBindingGroup(&.{
        .{ .binding_type = .StorageBuffer },
        .{ .binding_type = .Texture },
        .{ .binding_type = .Sampler },
    });

    self.buffer = try resources.createBuffer(
        .{
            .size = @sizeOf(Mat4) + MAX_GLYPHS * @sizeOf(GlyphData),
            .usage = .Storage,
        },
    );

    // what if we just make the texture one talllll texture?
    // this would make it super easy to just add the next glyph at an offset

    const tex_dimension: u32 = 16;

    // texture with no offset
    var pixels: [tex_dimension * tex_dimension]u8 = .{
        0, 255, 0, 255, 0, 0, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
        0, 255, 0, 255, 255, 255, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
        255, 255, 255, 255, 0, 0, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
        255, 0, 0, 255, 0, 0, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
        255, 255, 255, 255, 0, 0, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
        0, 0, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
        255, 255, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
        0, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
        0, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
    };

    resources.flipData(tex_dimension, tex_dimension, &pixels);
    self.texture = try resources.createTexture(.{
        .width = tex_dimension,
        .height = tex_dimension,
        .channels = 1,
        .flags = .{},
        .texture_type = .@"2d",
    }, &pixels);

    // okay lets add a 3
    var three: [4 * 7]u8 = .{
        255, 255, 255, 255, //
        0, 0, 0, 255, //
        0, 0, 255, 0, //
        0, 255, 0, 255, //
        0, 0, 0, 255, //
        255, 0, 0, 255, //
        0, 255, 255, 0, //
    };

    resources.flipData(4, 7, &three);

    try resources.updateTexture(self.texture, 0, &three, 7, tex_dimension - 7, 4, 7);

    self.sampler = try resources.createSampler(.{
        .filter = .nearest,
        .repeat = .wrap,
        .compare = .greater,
    });

    try resources.updateBindings(self.group, &[_]resources.BindingUpdate{
        .{ .binding = 0, .handle = self.buffer },
        .{ .binding = 1, .handle = self.texture },
        .{ .binding = 2, .handle = self.sampler },
    });
    // create our shader pipeline
    self.pipeline = try resources.createPipeline(.{
        .stages = &.{
            .{
                .bindpoint = .Vertex,
                .path = "font_example/assets/font.vert.spv",
            },
            .{
                .bindpoint = .Fragment,
                .path = "font_example/assets/font.frag.spv",
            },
        },
        .binding_groups = &.{self.group},
        .renderpass = renderpass,
        .cull_mode = .back,
    });
    self.atlas_pipeline = try resources.createPipeline(.{
        .stages = &.{
            .{
                .bindpoint = .Vertex,
                .path = "font_example/assets/atlas.vert.spv",
            },
            .{
                .bindpoint = .Fragment,
                .path = "font_example/assets/atlas.frag.spv",
            },
        },
        .binding_groups = &.{self.group},
        .renderpass = renderpass,
        .cull_mode = .none,
        .vertex_inputs = &.{ .Vec3, .Vec2 },
        .push_const_size = @sizeOf(Mat4),
    });

    return self;
}

/// look up the glyph location in the texture
/// TOOD: will add glyphs not in the texture
fn getGlyphLoc(codepoint: u32) Vec4 {
    return switch (codepoint) {
        109 => Vec4.new(4, 5, 3, 0),
        36 => Vec4.new(3, 9, 0, 0),
        51 => Vec4.new(4, 7, 7, 0),
        else => Vec4{},
    };
}

pub fn addGlyph(
    self: *Self,
    /// character we are printing
    codepoint: u32,
    /// position of bottom right corner
    pos: Vec2,
    /// font height in pixels 
    height: f32,
) !void {
    // TODO: look up the codepoint
    // TODO: add to the texture if not there

    // convert from points to pixels
    // assumes a ppi of 96
    const cell_height = self.bdf.header.size_p * @intToFloat(f32, self.bdf.header.size_y) / 96.0;

    const glyph = try self.bdf.getGlyph(codepoint);
    const size = .{
        .x = glyph.bb.x * (height / cell_height),
        .y = glyph.bb.y * (height / cell_height),
    };

    _ = try renderer.updateBuffer(
        self.buffer,
        @sizeOf(Mat4) + (@sizeOf(GlyphData) * self.index_offset),
        GlyphData,
        &[_]GlyphData{
            .{
                .rect = Vec4.new(pos.x, pos.y, size.x, size.y),
                .bb = getGlyphLoc(codepoint),
            },
        },
    );

    // for packing into the indices
    const Index = packed struct {
        index: u24,
        corner: u8,
    };

    _ = try renderer.updateBuffer(self.inds, @sizeOf(u32) * self.index_offset * 6, u32, &[_]u32{
        @bitCast(u32, Index{
            .corner = 0,
            .index = @intCast(u24, self.index_offset),
        }),
        @bitCast(u32, Index{
            .corner = 1,
            .index = @intCast(u24, self.index_offset),
        }),
        @bitCast(u32, Index{
            .corner = 2,
            .index = @intCast(u24, self.index_offset),
        }),
        @bitCast(u32, Index{
            .corner = 2,
            .index = @intCast(u24, self.index_offset),
        }),
        @bitCast(u32, Index{
            .corner = 3,
            .index = @intCast(u24, self.index_offset),
        }),
        @bitCast(u32, Index{
            .corner = 0,
            .index = @intCast(u24, self.index_offset),
        }),
    });

    self.index_offset += 1;
}

/// draw the glyphs in the buffer
pub fn drawGlyphs(self: Self, cmd: *CmdBuf) !void {
    try cmd.bindPipeline(self.pipeline);

    // draw the quads
    try cmd.drawIndexed(.{
        .count = self.index_offset * 6,
        .vertex_handle = .{},
        .index_handle = self.inds,
    });
}

/// draw the full texture atlass
pub fn drawAtlas(
    self: Self,
    cmd: *CmdBuf,
    x: f32,
    y: f32,
    w: f32,
    h: f32,
) !void {
    try cmd.bindPipeline(self.atlas_pipeline);

    const bufs = try quad.getBuffers();
    try cmd.pushConst(
        self.atlas_pipeline,
        Mat4.scale(Vec3.new(w, h, 0))
            .mul(Mat4.translate(Vec3.new(x + w / 2, y + h / 2, 0))),
    );
    // draw the quad
    try cmd.drawIndexed(.{
        .count = 6,
        .vertex_handle = bufs.vertices,
        .index_handle = bufs.indices,
        .offsets = &.{ 0, 4 * @sizeOf(Vec3) },
    });
}

pub fn clear(self: *Self) void {
    self.index_offset = 0;
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.bdf.glyphs);
    self.allocator.free(self.bdf.codepoints);
}
