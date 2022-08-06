const std = @import("std");
const octal = @import("octal");
const renderer = octal.renderer;
const resources = octal.renderer.resources;
const font = octal.font;
const mmath = octal.mmath;

const Allocator = std.mem.Allocator;
const Vec2 = mmath.Vec2;
const Vec4 = mmath.Vec4;
const Mat4 = mmath.Mat4;

const Self = @This();

const GlyphData = struct {
    rect: Vec4,
    bb: Vec4,
};

const MAX_GLYPHS = 1024;

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

allocator: Allocator,

/// offset into the index buffer
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

    const tex_dimension: u32 = 16;
    const channels: u32 = 1;

    // texture with no offset
    var pixels: [tex_dimension * tex_dimension * channels]u8 = .{
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

    self.texture = try resources.createTexture(.{
        .width = tex_dimension,
        .height = tex_dimension,
        .channels = channels,
        .flags = .{},
        .texture_type = .@"2d",
    }, &pixels, true);

    self.sampler = try resources.createSampler(.{
        .filter = .nearest,
        .repeat = .wrap,
        .compare = .greater,
    });
    _ = renderpass;

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

    return self;
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
    // add the indices and vertices

    // convert from points to pixels
    // assumes a ppi of 96
    const cell_height = self.bdf.header.size_p * @intToFloat(f32, self.bdf.header.size_y) / 96.0;

    const glyph = try self.bdf.getGlyph(codepoint);
    const size = .{
        // TODO: magic nubmer 1.33 is points to pixels
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

/// look up the glyph location in the texture
/// TOOD: will add glyphs not in the texture
fn getGlyphLoc(codepoint: u32) Vec4 {
    return switch (codepoint) {
        109 => Vec4.new(4, 5, 3, 0),
        36 => Vec4.new(3, 9, 0, 0),
        else => Vec4{},
    };
}

pub fn clear(self: *Self) void {
    self.index_offset = 0;
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.bdf.glyphs);
    self.allocator.free(self.bdf.codepoints);
}
