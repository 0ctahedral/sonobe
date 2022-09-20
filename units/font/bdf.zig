//! all the font loading code!
//! starting with bdf, then we can do ttf

const std = @import("std");
const utils = @import("utils");
const Allocator = std.mem.Allocator;

/// bounding box for glyphs
const BoundingBox = struct {
    x: u32 = 0,
    y: u32 = 0,
    x_off: i32 = 0,
    y_off: i32 = 0,
};
const DevWidth = struct {
    x: u32 = 0,
    y: u32 = 0,
};
pub const Glyph = struct {
    dwidth: DevWidth = .{},
    // TODO: make this configurable
    bitmap: [16]u8 = [_]u8{0} ** 16,
    bb: BoundingBox = .{},

    pub fn writeToTex(
        self: @This(),
        tex: []u8,
        x_off: usize,
        y_off: usize,
        width: usize,
    ) !void {
        if (@intCast(usize, self.bb.x * self.bb.y) > tex.len) return error.TextureSliceTooSmall;
        // for each row we loop over the bits and set them to 255 if the bit is set
        var row: usize = 0;
        while (row < @intCast(usize, self.bb.y)) : (row += 1) {
            var i: usize = 0;
            while (i < 8) : (i += 1) {
                if ((self.bitmap[row] >> @intCast(u3, 7 - i)) & 0x1 != 0) {
                    tex[(y_off + row) * width + (x_off + i)] = 255;
                }
            }
        }
    }
};

const BDF = @This();

const BDFHeader = struct {

    /// point
    size_p: f32 = 0,
    /// dpi x
    size_x: u8 = 0,
    /// dpi y
    size_y: u8 = 0,

    bb: BoundingBox = .{},
};

// TODO: for now we skip properties
header: BDFHeader,

/// codepoints for each glpyph
codepoints: []u32 = &[_]u32{},
glyphs: []Glyph = &[_]Glyph{},

pub fn init(path: []const u8, allocator: Allocator) !BDF {
    // open file
    var f = try std.fs.cwd().openFile(path, .{ .read = true });
    defer f.close();
    var buf = try allocator.alloc(u8, (try f.stat()).size);
    defer allocator.free(buf);
    _ = try f.readAll(buf);

    var header = BDFHeader{};
    var n_glyphs: usize = 0;

    const off = try parseHeader(&header, &n_glyphs, buf);

    var bdf = BDF{
        .header = header,
    };
    bdf.glyphs = try allocator.alloc(Glyph, n_glyphs);
    bdf.codepoints = try allocator.alloc(u32, n_glyphs);

    var fsoff: usize = off;
    var line: []u8 = undefined;
    // var lnum: usize = 0;
    // what glyph we on
    var idx: usize = 0;
    // what glyph we on
    while (std.mem.indexOf(u8, buf[fsoff..], "\n")) |feoff| {
        line = buf[fsoff .. fsoff + feoff];
        // CHARACTER STUFF
        if (std.mem.startsWith(u8, line, "STARTCHAR")) {
            const parse_offset = try parseGlyph(&bdf, idx, buf[fsoff + feoff ..]);
            fsoff = fsoff + feoff + parse_offset;
            idx += 1;
        } else {
            fsoff += feoff + 1;
        }
    }

    return bdf;
}

/// returns a glyph for a codepoint
pub fn getGlyph(self: @This(), codepoint: u32) !Glyph {
    // TODO: faster way of searching
    for (self.codepoints) |cp, i| {
        if (cp == codepoint) {
            return self.glyphs[i];
        }
    }

    return error.CouldNotFind;
}

fn parseHeader(header: *BDFHeader, n_glyphs: *usize, buf: []u8) !usize {
    var fsoff: usize = 0;
    var line: []u8 = undefined;
    var lnum: usize = 0;
    while (std.mem.indexOf(u8, buf[fsoff..], "\n")) |feoff| {
        line = buf[fsoff .. fsoff + feoff];
        // HEADER STUFF
        if (std.mem.startsWith(u8, line, "STARTFONT")) {
            //
        } else if (std.mem.startsWith(u8, line, "SIZE")) {
            var off: usize = 5;
            var eoff: usize = std.mem.indexOf(u8, line[off..], " ") orelse return error.Malformed;
            header.size_p = try std.fmt.parseFloat(f32, line[off .. off + eoff]);
            off = off + eoff + 1;

            eoff = std.mem.indexOf(u8, line[off..], " ") orelse return error.Malformed;
            header.size_x = try std.fmt.parseInt(u8, line[off .. off + eoff], 0);
            off = off + eoff + 1;

            header.size_y = try std.fmt.parseInt(u8, line[off..], 0);
        } else if (std.mem.startsWith(u8, line, "FONTBOUNDINGBOX")) {
            var off: usize = 16;
            var eoff: usize = std.mem.indexOf(u8, line[off..], " ") orelse return error.Malformed;
            header.bb.x = try std.fmt.parseInt(u32, line[off .. off + eoff], 0);
            off = off + eoff + 1;

            eoff = std.mem.indexOf(u8, line[off..], " ") orelse return error.Malformed;
            header.bb.y = try std.fmt.parseInt(u32, line[off .. off + eoff], 0);
            off = off + eoff + 1;

            eoff = std.mem.indexOf(u8, line[off..], " ") orelse return error.Malformed;
            header.bb.x_off = try std.fmt.parseInt(i32, line[off .. off + eoff], 0);
            off = off + eoff + 1;

            header.bb.y_off = try std.fmt.parseInt(i32, line[off..], 0);
        } else if (std.mem.startsWith(u8, line, "CHARS ")) {
            n_glyphs.* = try std.fmt.parseInt(u32, line[6..], 0);
            return fsoff + feoff + 1;
        }

        fsoff += feoff + 1;
        lnum += 1;
    }

    return error.ShouldNotGetHere;
}

fn parseGlyph(bdf: *BDF, idx: usize, buf: []u8) !usize {
    var fsoff: usize = 0;
    var line: []u8 = undefined;
    var lnum: usize = 0;
    var glyph: Glyph = .{};
    while (std.mem.indexOf(u8, buf[fsoff..], "\n")) |feoff| {
        line = buf[fsoff .. fsoff + feoff];
        // CHARACTER STUFF
        if (std.mem.startsWith(u8, line, "ENCODING")) {
            const cp = try std.fmt.parseInt(u32, line[9..], 0);
            bdf.codepoints[idx] = cp;
        } else if (std.mem.startsWith(u8, line, "DWIDTH")) {
            var off: usize = 7;
            var eoff: usize = std.mem.indexOf(u8, line[off..], " ") orelse return error.Malformed;
            glyph.dwidth.x = try std.fmt.parseInt(u8, line[off .. off + eoff], 0);
            off += eoff + 1;
            glyph.dwidth.y = try std.fmt.parseInt(u8, line[off..], 0);
        } else if (std.mem.startsWith(u8, line, "BBX")) {
            var off: usize = 4;
            var eoff: usize = std.mem.indexOf(u8, line[off..], " ") orelse return error.Malformed;
            glyph.bb.x = try std.fmt.parseInt(u32, line[off .. off + eoff], 0);
            off = off + eoff + 1;

            eoff = std.mem.indexOf(u8, line[off..], " ") orelse return error.Malformed;
            glyph.bb.y = try std.fmt.parseInt(u32, line[off .. off + eoff], 0);
            off = off + eoff + 1;

            eoff = std.mem.indexOf(u8, line[off..], " ") orelse return error.Malformed;
            glyph.bb.x_off = try std.fmt.parseInt(i32, line[off .. off + eoff], 0);
            off = off + eoff + 1;

            glyph.bb.y_off = try std.fmt.parseInt(i32, line[off..], 0);
        } else if (std.mem.startsWith(u8, line, "BITMAP")) {
            var row: usize = 0;
            // now we are in the bitmap section
            var start: usize = fsoff + feoff + 1;
            var eol: usize = 0;

            // get next line
            while (row < @intCast(usize, glyph.bb.y)) : (row += 1) {
                eol = start + std.mem.indexOf(u8, buf[start..], "\n").?;
                glyph.bitmap[row] = std.fmt.parseInt(u8, buf[start..eol], 16) catch {
                    utils.log.debug("invalid row: {s}\n", .{buf[start..eol]});
                    return error.GlyphBitmapFail;
                };

                start = eol + 1;
            }
            fsoff = eol + 1;

            // next should be end char
            continue;
        } else if (std.mem.startsWith(u8, line, "ENDCHAR")) {
            bdf.glyphs[idx] = glyph;
            return (fsoff + feoff + 1);
        }

        fsoff += feoff + 1;
        lnum += 1;
    }

    return error.GlyphNotEnded;
}

test "load scientifica" {
    const allocator = std.testing.allocator;
    const bdf = try BDF.init("./assets/fonts/scientifica-11.bdf", allocator);
    const dim = 4;
    var bitmap: [4 * 7]u8 = undefined;
    for (bitmap) |*r| {
        r.* = 0;
    }

    // write dollar to the texture
    const three = (try bdf.getGlyph(@as(u32, '3')));
    utils.log.debug("{}\n", .{three});
    try three.writeToTex(&bitmap, 0, 0, dim);

    for (bitmap) |b, i| {
        utils.log.debug("{d}, ", .{b});
        if ((i + 1) % dim == 0) {
            utils.log.debug("//\n", .{});
        }
    }

    defer allocator.free(bdf.glyphs);
    defer allocator.free(bdf.codepoints);
}

test "test glyph" {
    const allocator = std.testing.allocator;
    const bdf = try BDF.init("./assets/fonts/scientifica-11.bdf", allocator);

    try std.testing.expectEqual(bdf.getGlyph(@as(u32, 'm')), Glyph{
        .dwidth = .{ .x = 5 },
        // TODO: make this configurable
        .bitmap = [_]u8{ 0x90, 0xF0, 0x90, 0x90, 0x90 } ++ [_]u8{0} ** 11,
        .bb = .{ .x = 4.0, .y = 5.0 },
    });

    defer allocator.free(bdf.glyphs);
    defer allocator.free(bdf.codepoints);
}
