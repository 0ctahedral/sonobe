const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const math = @import("../sonobe.zig").math;
const Vec3 = math.Vec3;
const Vec2 = math.Vec2;
const Mesh = @import("mesh.zig").Mesh;

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

const Primitive = struct {
    /// accessor for indices
    ind: usize,
    pos: usize,
    uv: usize,
    norm: usize,
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

const JsonChunk = struct {
    accessors: ArrayList(Accessor),
    bufviews: ArrayList(BufView),
    // TODO: make list??
    primitive: Primitive,

    const Self = @This();

    pub fn init(buf: []const u8, allocator: Allocator) !Self {
        var self = Self{
            .accessors = ArrayList(Accessor).init(allocator),
            .bufviews = ArrayList(BufView).init(allocator),
            .primitive = undefined,
        };

        var parser = std.json.Parser.init(allocator, false);
        defer parser.deinit();

        var tree = try parser.parse(buf);
        defer tree.deinit();
        var mesh_listes = tree.root.Object.get("meshes").?.Array;

        for (mesh_listes.items) |m, i| {
            std.debug.print("\nmesh_list[{}]\n", .{i});
            var prims = m.Object.get("primitives").?.Array;
            for (prims.items) |p, j| {
                // ASSUME THE MODE IS ALWAYS TRIANGLES
                if (p.Object.get("mode")) |mode| {
                    try std.testing.expect(mode.Integer == 4);
                }

                const attrs = p.Object.get("attributes").?.Object;
                self.primitive = .{
                    .ind = @intCast(usize, p.Object.get("indices").?.Integer),
                    .pos = @intCast(usize, attrs.get("POSITION").?.Integer),
                    .uv = @intCast(usize, attrs.get("TEXCOORD_0").?.Integer),
                    .norm = @intCast(usize, attrs.get("NORMAL").?.Integer),
                };

                std.debug.print("primitive[{}] = {}\n", .{ j, self.primitive });
            }
        }

        for (tree.root.Object.get("accessors").?.Array.items) |a, i| {
            const obj = a.Object;
            const acc = Accessor{
                .view_num = @intCast(usize, obj.get("bufferView").?.Integer),
                .offset = @intCast(usize, if (obj.get("byteOffset")) |b| b.Integer else 0),
                .count = @intCast(usize, obj.get("count").?.Integer),
            };
            try self.accessors.append(acc);
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
            try self.bufviews.append(bv);
            std.debug.print("bv[{}]: {}\n", .{ i, bv });
        }

        var buffers = tree.root.Object.get("buffers").?.Array;
        for (buffers.items) |b, i| {
            std.debug.print("buf[{}] len = {}\n", .{ i, b.Object.get("byteLength").?.Integer });
        }
        return self;
    }

    pub fn deinit(self: Self) void {
        self.bufviews.deinit();
        self.accessors.deinit();
    }
};

fn addFromBuf(comptime T: type, arr: *ArrayList(T), acc: Accessor, view: BufView, buf: []const u8) !void {
    var offset = view.offset + acc.offset;
    const stride = view.stride orelse 0;
    var i: usize = 0;
    while (i < acc.count) : ({
        i += 1;
        offset += stride + @sizeOf(T);
    }) {
        const ptr = @ptrCast([*]const T, @alignCast(@alignOf(T), buf[offset .. offset + @sizeOf(T)]));
        //TODO: Vec3.fromSlice
        try arr.append(ptr[0]);
    }
}

fn getMesh(data: JsonChunk, buf: []const u8, mesh: *Mesh) !void {
    {
        // doing their own thing because we have type conversion
        // okay lets read some indices
        const ind_acc = data.accessors.items[data.primitive.ind];
        const ind_view = data.bufviews.items[ind_acc.view_num];
        const offset = ind_view.offset + ind_acc.offset;
        const inds = @ptrCast([*]const u16, @alignCast(4, buf[offset .. offset + ind_view.len]))[0..ind_acc.count];
        try mesh.indices.ensureTotalCapacity(inds.len);
        for (inds) |i| {
            try mesh.indices.append(@as(u32, i));
        }
    }

    {
        const pos_acc = data.accessors.items[data.primitive.pos];
        const pos_view = data.bufviews.items[pos_acc.view_num];
        try addFromBuf(Vec3, &mesh.positions, pos_acc, pos_view, buf);
    }

    {
        const uv_acc = data.accessors.items[data.primitive.uv];
        const uv_view = data.bufviews.items[uv_acc.view_num];
        try addFromBuf(Vec2, &mesh.uvs, uv_acc, uv_view, buf);
    }

    {
        const norm_acc = data.accessors.items[data.primitive.norm];
        const norm_view = data.bufviews.items[norm_acc.view_num];
        try addFromBuf(Vec3, &mesh.normals, norm_acc, norm_view, buf);
    }
}

pub fn MeshFromGltf(
    path: []const u8,
    allocator: Allocator,
) !Mesh {
    // get the reader from the file
    var file = try std.fs.cwd().openFile(path, .{ .read = true });
    defer file.close();
    const reader = file.reader();

    var data: JsonChunk = undefined;
    defer data.deinit();

    var mesh = Mesh.init(allocator);

    // read the header, we don't really care about that rn
    _ = try reader.readStruct(FileHeader);

    // for each chunk:
    var chunk = try reader.readStruct(ChunkHeader);
    try std.testing.expect(chunk.chunk_type == 0x4E4F534A);

    if (chunk.chunk_type == 0x4E4F534A) {
        var buf = try allocator.alloc(u8, chunk.len);
        defer allocator.free(buf);
        _ = try reader.readAll(buf);
        data = try JsonChunk.init(buf, allocator);
    }

    chunk = try reader.readStruct(ChunkHeader);
    try std.testing.expect(chunk.chunk_type == 0x004E4942);

    if (chunk.chunk_type == 0x004E4942) {
        var buf = try allocator.alloc(u8, chunk.len);
        defer allocator.free(buf);
        _ = try reader.readAll(buf);
        try getMesh(data, buf, &mesh);
    }

    return mesh;
}

//test "box_binary_gltf" {
//    const allocator = std.testing.allocator;
//    const path = "assets/Box.glb";
//
//    const mesh = try MeshFromGltf(path, allocator);
//    defer mesh.deinit();
//    std.debug.print("inds: {any}\n", .{mesh.indices.items});
//    for (mesh.positions.items) |p| {
//        std.debug.print("pos: {d:.2}, {d:.2}, {d:.2}\n", .{ p.x, p.y, p.z });
//    }
//}

test "octahedron_binary_gltf" {
    const allocator = std.testing.allocator;
    const path = "assets/models/octahedron.glb";

    const mesh = try MeshFromGltf(path, allocator);
    defer mesh.deinit();
    std.debug.print("inds: {any}\n", .{mesh.indices.items});
    for (mesh.positions.items) |p| {
        std.debug.print("pos: {d:.2}, {d:.2}, {d:.2}\n", .{ p.x, p.y, p.z });
    }
}

test "seamus_binary_gltf" {
    const allocator = std.testing.allocator;
    const path = "assets/models/seamus.glb";
    const mesh = try MeshFromGltf(path, allocator);
    defer mesh.deinit();
    std.debug.print("inds: {any}\n", .{mesh.indices.items});
    for (mesh.positions.items) |p| {
        std.debug.print("pos: {d:.2}, {d:.2}, {d:.2}\n", .{ p.x, p.y, p.z });
    }
}
