//! all the font loading code!
//! starting with bdf, then we can do ttf

const std = @import("std");
const Allocator = std.mem.Allocator;

/// bounding box for glyphs
const BoundingBox = struct {
    x: i32 = 0,
    y: i32 = 0,
    x_off: i32 = 0,
    y_off: i32 = 0,
};
const DevWidth = struct {
    x: u32 = 0,
    y: u32 = 0,
};
const Glyph = struct {
    dwidth: DevWidth = .{},
    // TODO: make this configurable
    bitmap: [16]u8 = [_]u8{0} ** 16,
    bb: BoundingBox = .{},

    //pub fn toTex(self: @This()) [256]u8 {
    //    [256]u8
    //}
};
const BDF = struct {
    name: []const u8 = "",
    /// point
    size_p: u32 = 0,
    /// dpi x
    size_x: u8 = 0,
    /// dpi y
    size_y: u8 = 0,

    bb: BoundingBox = .{},

    // TODO: for now we skip properties

    /// codepoints for each glpyph
    codepoints: []u32 = &[_]u32{},
    glyphs: []Glyph = &[_]Glyph{},
};

fn parseHeader(bdf: *BDF, buf: []u8, allocator: Allocator) !usize {
    var fsoff: usize = 0;
    var line: []u8 = undefined;
    var lnum: usize = 0;
    while (std.mem.indexOf(u8, buf[fsoff..], "\n")) |feoff| {
        line = buf[fsoff .. fsoff + feoff];
        // HEADER STUFF
        if (std.mem.startsWith(u8, line, "STARTFONT")) {
            std.debug.print("font version and stuff: {s}\n", .{line});
        } else if (std.mem.startsWith(u8, line, "SIZE")) {
            var off: usize = 5;
            var eoff: usize = std.mem.indexOf(u8, line[off..], " ") orelse return error.Malformed;
            bdf.size_p = try std.fmt.parseInt(u8, line[off .. off + eoff], 0);
            off = off + eoff + 1;

            eoff = std.mem.indexOf(u8, line[off..], " ") orelse return error.Malformed;
            bdf.size_x = try std.fmt.parseInt(u8, line[off .. off + eoff], 0);
            off = off + eoff + 1;

            bdf.size_y = try std.fmt.parseInt(u8, line[off..], 0);
        } else if (std.mem.startsWith(u8, line, "FONTBOUNDINGBOX")) {
            var off: usize = 16;
            var eoff: usize = std.mem.indexOf(u8, line[off..], " ") orelse return error.Malformed;
            bdf.bb.x = try std.fmt.parseInt(i32, line[off .. off + eoff], 0);
            off = off + eoff + 1;

            eoff = std.mem.indexOf(u8, line[off..], " ") orelse return error.Malformed;
            bdf.bb.y = try std.fmt.parseInt(i32, line[off .. off + eoff], 0);
            off = off + eoff + 1;

            eoff = std.mem.indexOf(u8, line[off..], " ") orelse return error.Malformed;
            bdf.bb.x_off = try std.fmt.parseInt(i32, line[off .. off + eoff], 0);
            off = off + eoff + 1;

            bdf.bb.y_off = try std.fmt.parseInt(i32, line[off..], 0);
        } else if (std.mem.startsWith(u8, line, "CHARS ")) {
            const n_glyphs = try std.fmt.parseInt(u32, line[6..], 0);
            bdf.glyphs = try allocator.alloc(Glyph, n_glyphs);
            bdf.codepoints = try allocator.alloc(u32, n_glyphs);
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
            glyph.bb.x = try std.fmt.parseInt(i32, line[off .. off + eoff], 0);
            off = off + eoff + 1;

            eoff = std.mem.indexOf(u8, line[off..], " ") orelse return error.Malformed;
            glyph.bb.y = try std.fmt.parseInt(i32, line[off .. off + eoff], 0);
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
            while (row < glyph.bb.y) : (row += 1) {
                eol = start + std.mem.indexOf(u8, buf[start..], "\n").?;
                glyph.bitmap[row] = std.fmt.parseInt(u8, buf[start..eol], 16) catch {
                    std.debug.print("invalid row: {s}\n", .{buf[start..eol]});
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

pub fn loadBDF(path: []const u8, allocator: Allocator) !BDF {
    // open file
    var f = try std.fs.cwd().openFile(path, .{ .read = true });
    defer f.close();
    // var reader = f.reader();
    // allocate buffer for whole font
    // this buffer should be enough for a line
    //var buf: [256]u8 = undefined;
    var buf = try allocator.alloc(u8, (try f.stat()).size);
    defer allocator.free(buf);
    _ = try f.readAll(buf);

    var bdf = BDF{};

    const off = try parseHeader(&bdf, buf, allocator);

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

test "scientifica" {
    const allocator = std.testing.allocator;
    const bdf = try loadBDF("./assets/scientifica-11.bdf", allocator);
    const dollar = bdf.glyphs[4];
    var bitmap: [16 * 16]u8 = undefined;
    for (bitmap) |*r| {
        r.* = 0;
    }

    // var srow: usize = @intCast(usize, bdf.bb.y - dollar.bb.y_off - dollar.bb.y);
    var row: usize = 0;
    while (row < dollar.bb.y) : (row += 1) {
        var i: usize = 0;
        while (i < 8) : (i += 1) {
            if ((dollar.bitmap[row] >> @intCast(u3, 7 - i)) & 0x1 != 0) {
                // bitmap[(srow + row) * 16 + (i + @intCast(usize, dollar.bb.x_off))] = 255;
                bitmap[(row * 16) + i] = 255;
            }
        }
    }

    for (bitmap) |b, i| {
        std.debug.print("{d}, ", .{b});
        if ((i + 1) % 16 == 0) {
            std.debug.print("//\n", .{});
        }
    }

    defer allocator.free(bdf.glyphs);
    defer allocator.free(bdf.codepoints);
}
