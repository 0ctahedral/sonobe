const std = @import("std");

const FileHeader = packed struct {
    magic: u32, // has to equal 0x46546C67
    version: u32, // should be 2
    // total length in bytes
    len: u32,
};

const ChunkHeader = packed struct {
    len: u32,
    // JSON = 0x4E4F534A or BIN = 0x004E4942
    chunk_type: u32,
};

const ArrayList = std.ArrayList;

/// Geometry to be rendered with the given material.
pub const Primitive = struct {
    attributes: ArrayList(usize),
    /// The topology type of primitives to render.
    mode: u32,
    /// The index of the accessor that contains the vertex indices.
    indices: ?usize = null,
    /// The index of the material to apply to this primitive when rendering.
    material: ?usize = null,
};

/// A set of primitives to be rendered. 
/// Its global transform is defined by a node that references it.
pub const Mesh = struct {
    /// The user-defined name of this object.
    name: []const u8,
    /// An array of primitives, each defining geometry to be rendered.
    primitives: ArrayList(Primitive),
};

test "binary gltf" {
    var file = try std.fs.cwd().openFile("assets/Box.glb", .{ .read = true });
    defer file.close();
    const reader = file.reader();
    _ = try reader.readStruct(FileHeader);
    var chunk = try reader.readStruct(ChunkHeader);
    var buf: [1024]u8 = undefined;
    const json_slice = buf[0..chunk.len];
    _ = try reader.read(json_slice);
    var stream = std.json.TokenStream.init(json_slice);
    while (try stream.next()) |tok| {
        switch (tok) {
            .String => |s| {
                if (std.mem.eql(u8, s.slice(json_slice, stream.i - 1), "meshes")) {
                    std.json.parse(std.ArrayList(Mesh), &stream, .{ .allocator = std.testing.allocator });
                }
            },
            else => {},
        }
    }
}
