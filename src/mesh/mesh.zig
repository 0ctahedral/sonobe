const std = @import("std");
const math = @import("../math.zig");
const renderer = @import("../renderer.zig");
const resources = renderer.resources;
const Vec3 = math.Vec3;
const Vec2 = math.Vec2;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

/// A mutable mesh type
pub const Mesh = struct {
    indices: ArrayList(u32),
    positions: ArrayList(Vec3),
    uvs: ArrayList(Vec2),
    buffers: ?Buffers = null,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .positions = ArrayList(Vec3).init(allocator),
            .indices = ArrayList(u32).init(allocator),
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

        self.buffers = Buffers{
            .vertices = try resources.createBuffer(
                .{
                    .size = self.uvs.items.len * @sizeOf(Vec2) + self.positions.items.len * @sizeOf(Vec3),
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

        var offset = try renderer.updateBuffer(self.buffers.?.vertices, 0, Vec3, self.positions.items);
        offset = try renderer.updateBuffer(self.buffers.?.vertices, offset, Vec2, self.uvs.items);
        _ = try renderer.updateBuffer(self.buffers.?.indices, 0, u32, self.indices.items);

        return self.buffers.?;
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

        self.buffers = Buffers{
            .vertices = try resources.createBuffer(
                .{
                    .size = self.uvs.len * @sizeOf(Vec2) + self.positions.len * @sizeOf(Vec3),
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

        var offset = try renderer.updateBuffer(self.buffers.?.vertices, 0, Vec3, self.positions);
        offset = try renderer.updateBuffer(self.buffers.?.vertices, offset, Vec2, self.uvs);
        _ = try renderer.updateBuffer(self.buffers.?.indices, 0, u32, self.indices);

        return self.buffers.?;
    }
};

pub const Buffers = struct {
    vertices: renderer.Handle = .{},
    indices: renderer.Handle = .{},
};
