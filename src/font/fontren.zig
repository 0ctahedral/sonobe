const std = @import("std");
const renderer = @import("../renderer.zig");
const resources = renderer.resources;
const quad = @import("../mesh.zig").quad;
const math = @import("../math.zig");
const BDF = @import("bdf.zig");

const Allocator = std.mem.Allocator;

const CmdBuf = renderer.CmdBuf;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const Mat4 = math.Mat4;

const Self = @This();

const GlyphData = struct {
    rect: Vec4,
    bb: Vec4,
    color: Vec4,
};

const MAX_GLYPHS = 1024;

allocator: Allocator,

bdf: BDF,
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

bb_cache: Cache,

/// dimension of the texture atlas
atlas_dimension: u32 = 120,

/// a really shitty cache for offsets into the texture
const Cache = struct {
    map: std.AutoHashMap(u32, Vec4),
    next_index: u32 = 0,
};
pub fn init(path: []const u8, renderpass: renderer.Handle, allocator: Allocator) !Self {
    var self = Self{
        .allocator = allocator,
        .bdf = try BDF.init(path, allocator),
        .bb_cache = .{
            .map = std.AutoHashMap(u32, Vec4).init(allocator),
        },
    };

    self.atlas_dimension = self.bdf.header.bb.y * 10;

    self.inds = try resources.createBuffer(
        .{
            .size = MAX_GLYPHS * 6 * @sizeOf(u32),
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
            .size = @sizeOf(Mat4) + (2 * @sizeOf(Vec2)) + MAX_GLYPHS * @sizeOf(GlyphData),
            .usage = .Storage,
        },
    );
    _ = try renderer.updateBuffer(
        self.buffer,
        @sizeOf(Mat4),
        Vec2,
        &[_]Vec2{
            Vec2.new(
                @intToFloat(f32, self.atlas_dimension),
                @intToFloat(f32, self.atlas_dimension),
            ),
            Vec2.new(
                @intToFloat(f32, self.bdf.header.bb.x),
                @intToFloat(f32, self.bdf.header.bb.y),
            ),
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
                .path = "assets/shaders/font.vert.spv",
            },
            .{
                .bindpoint = .Fragment,
                .path = "assets/shaders/font.frag.spv",
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
                .path = "assets/shaders/atlas.vert.spv",
            },
            .{
                .bindpoint = .Fragment,
                .path = "assets/shaders/atlas.frag.spv",
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
    // TODO: throw error if texture is too full
    // write to the pixels array
    const cell = self.bdf.header.bb;
    // first get offset in cells
    // then we can convert to texels
    const ncol = self.atlas_dimension / cell.x;

    const xoff = self.bb_cache.next_index % ncol;
    const yoff = ((self.bb_cache.next_index - xoff) / ncol);

    // put a bunch of pixels on the stack
    var pixels: [256]u8 = [_]u8{0} ** 256;
    // get our glyph
    const glyph = try self.bdf.getGlyph(codepoint);
    try glyph.writeToTex(&pixels, 0, 0, cell.x);
    // flip it
    resources.flipData(cell.x, cell.y, &pixels);
    const xoff_pix = cell.x * xoff;
    //const yoff_pix = self.atlas_dimension - (yoff * cell.y);
    const yoff_pix = (yoff * cell.y);
    // write to the cell size
    try resources.updateTexture(
        self.texture,
        0,
        pixels[0 .. cell.x * cell.y],
        xoff_pix,
        yoff_pix,
        cell.x,
        cell.y,
    );

    const bb = .{
        .x = @intToFloat(f32, glyph.bb.x),
        .y = @intToFloat(f32, glyph.bb.y),
        .z = @intToFloat(f32, xoff_pix),
        .w = @intToFloat(f32, yoff_pix),
    };

    try self.bb_cache.map.put(codepoint, bb);
    self.bb_cache.next_index += 1;

    //for (pixels) |b, i| {
    //    std.debug.print("{d}, ", .{b});
    //    if ((i + 1) % 16 == 0) {
    //        std.debug.print("//\n", .{});
    //    }
    //}
    return bb;
}

/// adds glyphs from a string to the draw buffer and returns the offset
/// from the starting position
pub fn addString(
    self: *Self,
    /// character we are printing
    string: []const u8,
    /// position of bottom right corner
    pos: Vec2,
    /// font height in pixels 
    height: f32,
    /// the color of this string
    color: Vec4,
) !Vec2 {
    var offset = Vec2{};
    var max_y = height;
    for (string) |b| {
        // increase x offset by width of previous glyph
        const o = try self.addGlyph(
            @intCast(u32, b),
            pos.add(offset),
            height,
            color,
        );
        offset.x += o.x;
        max_y = @maximum(max_y, height + o.y);
    }

    offset.y = max_y;
    return offset;
}

/// adds a glyph to our render buffer
/// returns the x offset from that should be used for next glyph
/// and the y position
pub fn addGlyph(
    self: *Self,
    /// character we are printing
    codepoint: u32,
    /// position of bottom right corner
    pos: Vec2,
    /// font height in pixels 
    height: f32,
    /// the color of this glyph
    color: Vec4,
) !Vec2 {
    // convert from points to pixels
    // assumes a ppi of 96
    const cell_height = self.bdf.header.size_p * @intToFloat(f32, self.bdf.header.size_y) / 96.0;
    const ratio = height / cell_height;

    // bounding box in the texture
    const tex_bb = self.bb_cache.map.get(codepoint) orelse (try self.addGlyphToTexture(codepoint));

    const size = .{
        .x = tex_bb.x * ratio,
        .y = tex_bb.y * ratio,
    };

    const glyph = try self.bdf.getGlyph(codepoint);

    _ = try renderer.updateBuffer(
        self.buffer,
        @sizeOf(Mat4) + (2 * @sizeOf(Vec2)) + (@sizeOf(GlyphData) * self.index_offset),
        GlyphData,
        &[_]GlyphData{
            .{
                .rect = Vec4.new(
                    pos.x + @intToFloat(f32, glyph.bb.x_off) * ratio,
                    pos.y + (height - size.y) - @intToFloat(f32, glyph.bb.y_off) * ratio,
                    size.x,
                    size.y,
                ),
                .bb = tex_bb,
                .color = color,
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

    return Vec2.new(@intToFloat(f32, glyph.dwidth.x) * ratio, -@intToFloat(f32, glyph.bb.y_off) * ratio);
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
    /// solid uv
    uv,
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
        .vertex_offsets = &.{ 0, 4 * @sizeOf(Vec3) },
    });
}

pub fn clear(self: *Self) void {
    self.index_offset = 0;
}

pub fn deinit(self: *Self) void {
    self.bb_cache.map.deinit();
    self.allocator.free(self.bdf.glyphs);
    self.allocator.free(self.bdf.codepoints);
}
