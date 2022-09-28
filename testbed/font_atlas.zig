const std = @import("std");
const device = @import("device");
const resources = device.resources;

const BDF = @import("font").BDF;

const utils = @import("utils");
const log = utils.log.Logger("ui");
const Color = utils.Color;
const Handle = utils.Handle;

const math = @import("math");
const Vec2 = math.Vec2;

const Rect = @import("./ui.zig").Rect;

/// font atlas/cache datastructure
pub const FontAtlas = struct {
    /// data for a glyph in the atlas
    const Glyph = struct {
        /// bounds of the glyph size
        bb: Vec2,
        /// offset of glyph from parent bounding box
        offset: Vec2,
        /// lookup index in the atlas
        idx: u32,
    };

    const GlyphData = struct {
        /// rectangle that we will use to render this glyph
        rect: Rect,
        /// offset in pixels to draw next glyph
        next_offset: Vec2,
    };

    /// maps codepoint to glyph bounding box and index
    /// into the atlas texture
    /// TODO: replace hashmap with lru queue
    map: std.AutoHashMap(u32, Glyph),
    /// index of next glyph to be added to the atlas
    next_index: u32 = 0,

    /// font we are rendering from
    font: BDF,

    /// texture containing all the glyphs
    texture: Handle(.Texture) = .{},
    /// sampler for textures used by the gui system
    sampler: Handle(.Sampler) = .{},
    /// dimension of the atlas (its a square)
    dimension: u32,

    pub fn init(
        path: []const u8,
        allocator: std.mem.Allocator,
    ) !FontAtlas {
        var font = try BDF.init(path, allocator);
        const dim = font.header.bb.y * 10;

        return FontAtlas{
            .map = std.AutoHashMap(u32, Glyph).init(allocator),
            .font = font,
            .dimension = dim,
            .texture = try resources.createTextureEmpty(.{
                .width = dim,
                .height = dim,
                .channels = 1,
                .flags = .{},
                .texture_type = .@"2d",
            }),
            .sampler = try resources.createSampler(.{
                .filter = .nearest,
                .repeat = .wrap,
                .compare = .greater,
            }),
        };
    }

    pub fn deinit(self: *FontAtlas) void {
        self.map.deinit();
        self.font.deinit();
        resources.destroy(self.sampler.erased());
        resources.destroy(self.texture.erased());
    }

    /// looks up a glyph in the atlas and returns the
    /// associated data. adds the glyph if needed
    pub fn getGlyph(self: *FontAtlas, codepoint: u32) !Glyph {
        if (self.map.get(codepoint)) |g| {
            return g;
        }
        // TODO: throw error if texture is too full
        // write to the pixels array
        const cell = self.font.header.bb;
        // first get offset in cells
        // then we can convert to texels
        const ncol = self.dimension / cell.x;

        const xoff = self.next_index % ncol;
        const yoff = ((self.next_index - xoff) / ncol);

        // put a bunch of pixels on the stack
        var pixels: [256]u8 = [_]u8{0} ** 256;
        // get our glyph
        const glyph = try self.font.getGlyph(codepoint);
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

        const g = Glyph{
            .idx = self.next_index,
            .bb = .{
                .x = @intToFloat(f32, glyph.bb.x),
                .y = @intToFloat(f32, glyph.bb.y),
            },
            .offset = .{
                .x = @intToFloat(f32, glyph.bb.x_off),
                .y = @intToFloat(f32, glyph.bb.y_off),
            },
        };

        try self.map.put(codepoint, g);
        self.next_index += 1;

        return g;
    }

    pub fn getGlyphData(
        self: *FontAtlas,
        /// character we are printing
        codepoint: u32,
        /// position of bottom right corner
        pos: Vec2,
        /// font height in pixels 
        height: f32,
        // TODO: other glyph data, not just the rectangle
    ) ?GlyphData {
        // convert from points to pixels
        // assumes a ppi of 96
        const cell_height = self.font.header.size_p * @intToFloat(f32, self.font.header.size_y) / 96.0;
        const ratio = height / cell_height;

        // bounding box in the texture
        const glyph = self.getGlyph(codepoint) catch return null;

        const size = .{
            .x = glyph.bb.x * ratio,
            .y = glyph.bb.y * ratio,
        };

        const f_glyph = self.font.getGlyph(codepoint) catch return null;

        return GlyphData{
            .rect = .{
                .x = pos.x + glyph.offset.x * ratio,
                .y = pos.y + (height - size.y) - glyph.offset.y * ratio,
                .w = size.x,
                .h = size.y,
            },

            .next_offset = Vec2.new(
                @intToFloat(f32, f_glyph.dwidth.x) * ratio,
                -glyph.offset.y * ratio,
            ),
        };
    }
};
