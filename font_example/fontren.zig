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

/// offset into the index buffer
index_offset: u32 = 0,

/// a really shitty cache for offsets into the texture
bb_cache: std.AutoHashMap(u32, Vec4),
next_index: u32 = 0,

/// dimension of the texture atlas
atlas_dimension: u32 = 120,

pub fn init(path: []const u8, renderpass: renderer.Handle, allocator: Allocator) !Self {
    var self = Self{
        .allocator = allocator,
        .bdf = try font.loadBDF(path, allocator),
        .bb_cache = std.AutoHashMap(u32, Vec4).init(allocator),
    };

    self.atlas_dimension = self.bdf.header.bb.y * 10;

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

    self.texture = try resources.createTextureEmpty(.{
        .width = self.atlas_dimension,
        .height = self.atlas_dimension,
        .channels = 1,
        .flags = .{},
        .texture_type = .@"2d",
    });

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
        .push_const_size = @sizeOf(u32),
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

/// adds a glyph to the texture at a given offset in CELL SIZE
/// returns the bounding box for the glyph in texel space
fn addGlyphToTexture(
    self: *Self,
    codepoint: u32,
) !Vec4 {
    // write to the pixels array
    const cell = self.bdf.header.bb;
    const ncol = self.atlas_dimension / cell.x;
    const xoff = self.next_index % ncol;
    const yoff = (self.next_index - xoff) / cell.y;
    // put a bunch of pixels on the stack
    var pixels: [256]u8 = [_]u8{0} ** 256;
    // get our glyph
    const glyph = try self.bdf.getGlyph(codepoint);
    try glyph.writeToTex(&pixels, 0, 0, cell.x);
    // flip it
    resources.flipData(cell.x, cell.y, &pixels);
    // write to the cell size
    try resources.updateTexture(
        self.texture,
        0,
        pixels[0 .. cell.x * cell.y],
        cell.x * xoff,
        (self.atlas_dimension - ((yoff + 1) * cell.y)),
        cell.x,
        cell.y,
    );

    const bb = .{
        .x = @intToFloat(f32, glyph.bb.x),
        .y = @intToFloat(f32, glyph.bb.y),
        .z = @intToFloat(f32, cell.x * xoff),
        .w = @intToFloat(f32, cell.y * yoff),
    };

    try self.bb_cache.put(codepoint, bb);

    //for (pixels) |b, i| {
    //    std.debug.print("{d}, ", .{b});
    //    if ((i + 1) % 16 == 0) {
    //        std.debug.print("//\n", .{});
    //    }
    //}
    self.next_index += 1;
    return bb;
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
    const ratio = height / cell_height;

    // bounding box in the texture
    const tex_bb = self.bb_cache.get(codepoint) orelse (try self.addGlyphToTexture(codepoint));

    const size = .{
        .x = tex_bb.x * ratio,
        .y = tex_bb.y * ratio,
    };

    const bb = (try self.bdf.getGlyph(codepoint)).bb;

    _ = try renderer.updateBuffer(
        self.buffer,
        @sizeOf(Mat4) + (@sizeOf(GlyphData) * self.index_offset),
        GlyphData,
        &[_]GlyphData{
            .{
                .rect = Vec4.new(
                    pos.x - @intToFloat(f32, bb.x_off) * ratio,
                    pos.y - @intToFloat(f32, bb.y_off) * ratio,
                    size.x,
                    size.y,
                ),
                .bb = tex_bb,
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

    // TODO: this should be a shader variant with specialization const
    try cmd.pushConst(self.pipeline, @as(u32, 0));
    // draw the quads
    try cmd.drawIndexed(.{
        .count = self.index_offset * 6,
        .vertex_handle = .{},
        .index_handle = self.inds,
    });
}

pub const GlyphDebugMode = enum {
    /// same as drawGlyphs
    normal,
    /// with outlines for the quads
    outlined,
    /// solid quads
    solid,
};

/// draw the glyphs with some debugging
pub fn drawGlyphsDebug(self: Self, cmd: *CmdBuf, mode: GlyphDebugMode) !void {
    try cmd.bindPipeline(self.pipeline);

    // TODO: this should be a shader variant with specialization const
    try cmd.pushConst(self.pipeline, @as(u32, @enumToInt(mode)));
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
    self.bb_cache.deinit();
    self.allocator.free(self.bdf.glyphs);
    self.allocator.free(self.bdf.codepoints);
}
