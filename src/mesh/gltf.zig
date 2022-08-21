const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Vec3 = struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,
};

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

// a mesh for our purposes
pub const Mesh = struct {
    indices: ArrayList(u16),
    positions: ArrayList(Vec3),
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .positions = ArrayList(Vec3).init(allocator),
            .indices = ArrayList(u16).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: Self) void {
        self.indices.deinit();
        self.positions.deinit();
    }
};

const Primitive = struct {
    /// accessor for indices
    ind: usize,
    pos: usize,
};

const Accessor = struct {
    view_num: usize,
    offset: usize,
    count: usize,
};

const BufView = struct {
    buf_num: usize,
    offset: usize,
    len: usize,
    stride: ?usize,
};

test "binary gltf" {
    const allocator = std.testing.allocator;
    var file = try std.fs.cwd().openFile("assets/Box.glb", .{ .read = true });
    defer file.close();
    const reader = file.reader();
    _ = try reader.readStruct(FileHeader);
    var chunk = try reader.readStruct(ChunkHeader);
    try std.testing.expect(chunk.chunk_type == 0x4E4F534A);

    var buf = try allocator.alloc(u8, chunk.len);
    _ = try reader.readAll(buf);
    // defer allocator.free(buf);

    var parser = std.json.Parser.init(allocator, false);
    defer parser.deinit();

    var tree = try parser.parse(buf);
    defer tree.deinit();
    var meshes = tree.root.Object.get("meshes").?.Array;

    var primitive: Primitive = undefined;
    var accessors = ArrayList(Accessor).init(allocator);
    defer accessors.deinit();
    var buffer_views = ArrayList(BufView).init(allocator);
    defer buffer_views.deinit();

    for (meshes.items) |m, i| {
        std.debug.print("\nmesh[{}]\n", .{i});
        var prims = m.Object.get("primitives").?.Array;
        for (prims.items) |p, j| {
            // ASSUME THE MODE IS ALWAYS TRIANGLES
            const mode = p.Object.get("mode").?.Integer;
            try std.testing.expect(mode == 4);

            const attrs = p.Object.get("attributes").?.Object;
            primitive = .{
                .ind = @intCast(usize, p.Object.get("indices").?.Integer),
                .pos = @intCast(usize, attrs.get("POSITION").?.Integer),
            };

            std.debug.print("primitive[{}] = {}\n", .{ j, primitive });
        }
    }

    for (tree.root.Object.get("accessors").?.Array.items) |a, i| {
        const obj = a.Object;
        const acc = Accessor{
            .view_num = @intCast(usize, obj.get("bufferView").?.Integer),
            .offset = @intCast(usize, obj.get("byteOffset").?.Integer),
            .count = @intCast(usize, obj.get("count").?.Integer),
        };
        try accessors.append(acc);
        std.debug.print("accessor {}: {}\n", .{ i, acc });
    }

    for (tree.root.Object.get("bufferViews").?.Array.items) |v, i| {
        const obj = v.Object;
        const bv = BufView{
            .buf_num = @intCast(usize, obj.get("buffer").?.Integer),
            .offset = @intCast(usize, obj.get("byteOffset").?.Integer),
            .len = @intCast(usize, obj.get("byteLength").?.Integer),
            .stride = if (obj.get("byteStride")) |s| @intCast(usize, s.Integer) else null,
        };
        try buffer_views.append(bv);
        std.debug.print("bv[{}]: {}\n", .{ i, bv });
    }

    var buffers = tree.root.Object.get("buffers").?.Array;
    for (buffers.items) |b, i| {
        std.debug.print("buf[{}] len = {}\n", .{ i, b.Object.get("byteLength").?.Integer });
    }

    chunk = try reader.readStruct(ChunkHeader);
    std.debug.print("{}\n", .{chunk});
    try std.testing.expect(chunk.chunk_type == 0x004E4942);
    // try std.testing.expect(chunk.len == buffer_lens[0]);
    // read binary into a buffer
    allocator.free(buf);
    buf = try allocator.alloc(u8, chunk.len);
    _ = try reader.readAll(buf);
    defer allocator.free(buf);

    var mesh = Mesh.init(allocator);
    defer mesh.deinit();
    {
        // okay lets read some indices
        const ind_acc = accessors.items[primitive.ind];
        const ind_view = buffer_views.items[ind_acc.view_num];
        const offset = ind_view.offset + ind_acc.offset;
        const inds = @ptrCast([*]u16, @alignCast(4, buf[offset .. offset + ind_view.len]))[0..ind_acc.count];
        try mesh.indices.appendSlice(inds);
    }

    {
        const pos_acc = accessors.items[primitive.pos];
        const pos_view = buffer_views.items[pos_acc.view_num];
        var offset = pos_view.offset + pos_acc.offset;

        var i: usize = 0;
        while (i < pos_acc.count) : ({
            i += 1;
            offset += pos_view.stride.?;
        }) {
            const ptr = @ptrCast([*]Vec3, @alignCast(@alignOf(Vec3), buf[offset .. offset + @sizeOf(Vec3)]));
            // std.debug.print("off[{}]: {}\n", .{ offset, i });
            //TODO: vec from buf
            try mesh.positions.append(ptr[0]);
        }
    }

    std.debug.print("inds: {any}\n", .{mesh.indices.items});
    for (mesh.positions.items) |p| {
        std.debug.print("pos: {d:.2}, {d:.2}, {d:.2}\n", .{ p.x, p.y, p.z });
    }
}
