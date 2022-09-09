const std = @import("std");
const math = @import("math");
const device = @import("device");
const resources = device.resources;
const Handle = @import("utils").Handle;
const Vec3 = math.Vec3;
const Vec2 = math.Vec2;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

/// A mutable mesh type
pub const Mesh = struct {
    indices: ArrayList(u32),
    positions: ArrayList(Vec3),
    normals: ArrayList(Vec3),
    uvs: ArrayList(Vec2),
    buffers: ?Buffers = null,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .indices = ArrayList(u32).init(allocator),
            .positions = ArrayList(Vec3).init(allocator),
            .normals = ArrayList(Vec3).init(allocator),
            .uvs = ArrayList(Vec2).init(allocator),
        };
    }

    pub fn deinit(self: Self) void {
        self.indices.deinit();
        self.positions.deinit();
        self.uvs.deinit();
    }

    pub fn getBuffers(self: *Self) !Buffers {
        if (self.buffers) |b| return b;

        const uv_size = self.uvs.items.len * @sizeOf(Vec2);
        const normals_size = self.normals.items.len * @sizeOf(Vec3);
        const positions_size = self.positions.items.len * @sizeOf(Vec3);

        const buffers = Buffers{
            .positions_offset = 0,
            .normals_offset = positions_size,
            .uv_offset = positions_size + normals_size,
            .vertices = try resources.createBuffer(
                .{
                    .size = uv_size + normals_size + positions_size,
                    .usage = .Vertex,
                },
            ),
            .indices = try resources.createBuffer(
                .{
                    .size = self.indices.items.len * @sizeOf(u32),
                    .usage = .Index,
                },
            ),
        };

        _ = try resources.updateBufferTyped(
            buffers.vertices,
            buffers.positions_offset,
            Vec3,
            self.positions.items,
        );
        _ = try resources.updateBufferTyped(
            buffers.vertices,
            buffers.normals_offset,
            Vec3,
            self.normals.items,
        );
        _ = try resources.updateBufferTyped(
            buffers.vertices,
            buffers.uv_offset,
            Vec2,
            self.uvs.items,
        );
        _ = try resources.updateBufferTyped(buffers.indices, 0, u32, self.indices.items);

        self.buffers = buffers;

        return buffers;
    }
};

/// A constant mesh type
pub const ConstMesh = struct {
    positions: []const Vec3 = &[_]Vec3{},
    uvs: []const Vec2 = &[_]Vec2{},
    indices: []const u32 = &[_]u32{},
    buffers: ?Buffers = null,

    const Self = @This();

    pub fn getBuffers(self: *Self) !Buffers {
        if (self.buffers) |b| return b;

        const uv_size = self.uvs.len * @sizeOf(Vec2);
        // const normals_size = self.normals.items.len * @sizeOf(Vec3);
        const positions_size = self.positions.len * @sizeOf(Vec3);

        self.buffers = Buffers{
            .positions_offset = 0,
            // TODO: add
            .normals_offset = 0,
            .uv_offset = positions_size,
            .vertices = try resources.createBuffer(
                .{
                    .size = uv_size + positions_size,
                    .usage = .Vertex,
                },
            ),
            .indices = try resources.createBuffer(
                .{
                    .size = self.indices.len * @sizeOf(u32),
                    .usage = .Index,
                },
            ),
        };

        var offset = try resources.updateBufferTyped(self.buffers.?.vertices, 0, Vec3, self.positions);
        offset = try resources.updateBufferTyped(self.buffers.?.vertices, offset, Vec2, self.uvs);
        _ = try resources.updateBufferTyped(self.buffers.?.indices, 0, u32, self.indices);

        return self.buffers.?;
    }
};

pub const Buffers = struct {
    vertices: Handle(.Buffer) = .{},
    indices: Handle(.Buffer) = .{},
    uv_offset: usize,
    normals_offset: usize,
    positions_offset: usize,
};
