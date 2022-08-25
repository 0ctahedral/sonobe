const std = @import("std");
const testing = @import("std").testing;

/// indexing type for handles
/// cound consider making this configurable
const I = u32;

/// a nullable enum type
const Nullable = enum(I) {
    null_handle = 0,
    _,
};

/// contains an index which can be null
/// and a generation counter
/// const HandleType = packed struct {
pub fn Handle(_: anytype) type {
    return packed struct {
        /// "unique" identity of this handle
        // id: Nullable = .null_handle,
        id: I = 0,
        /// what generation does this handle belong to
        /// useful for reusing hanles when they are freed
        generation: I = 0,

        /// erase the type of this handle
        pub fn erase(self: @This()) ErasedHandle {
            return .{
                .id = self.id,
                .generation = self.generation,
            };
        }

        const Null = @This();
    };
}

pub const HandlePool = struct {
    pub const N = 8;
    const Self = @This();

    generations: [N]I = [_]I{0} ** N,

    /// ids that have been given back to the pool
    freed_ids: [N]I = [_]I{0} ** N,
    /// index of the last used id
    last_used: usize = 0,
    /// number of free ids
    n_free: usize = 0,

    pub fn alloc(self: *Self) !ErasedHandle {
        if (self.last_used < N) {
            const id = @intCast(I, self.last_used);
            self.last_used += 1;

            return ErasedHandle{
                .id = id,
                .generation = self.generations[@as(usize, id)],
            };
        }

        if (self.n_free > 0) {
            const idx = @as(usize, self.n_free);
            self.n_free -= 1;

            const id = self.freed_ids[idx];
            self.generations[@as(usize, id)] += 1;

            return ErasedHandle{
                .id = id,
                .generation = self.generations[@as(usize, id)],
            };
        }

        return error.OutOfHandles;
    }

    pub fn free(self: Self, h: ErasedHandle) void {
        // should this return an error if its out of date or just do nothing?
        testing.expect(self.generations[h.id] == h.generation);
        self.generations[h.id] += 1;

        self.freed_ids[self.n_free] = h.id;
        self.n_free += 1;
    }
};

/// A way of erasing the type of a handle
pub const ErasedHandle = Handle(null);

test "create one" {
    const b = Handle(.Buffer){};
    const s = Handle(.Seamus){};
    const g = Handle(null){};

    try testing.expect(@TypeOf(s) != @TypeOf(b));
    try testing.expect(@TypeOf(g) == ErasedHandle);
}

fn takesErased(h: ErasedHandle) void {
    std.debug.print("oopsies {}", .{h});
}

test "erase handle" {
    const b = Handle(.Bloopy){};
    // this should fail
    // takesErased(b);
    takesErased(b.erase());
}

test "alloc" {
    var pool = HandlePool{};

    var i: I = 0;
    while (i < HandlePool.N) : (i += 1) {
        const h = try pool.alloc();
        try testing.expect(h.id == i);
    }

    try testing.expectError(error.OutOfHandles, pool.alloc());
}

test "free" {
    var pool = HandlePool{};
    pool.last_used = HandlePool.N;

    try testing.expectError(error.OutOfHandles, pool.alloc());
}
