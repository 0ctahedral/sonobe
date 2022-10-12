const std = @import("std");
const testing = std.testing;

pub fn SparseSet(
    /// type we are using to index
    comptime I: type,
    /// type that stores a value
    comptime V: type,
) type {
    return struct {
        /// maximum number of elements
        const CAPACITY: u32 = 128;
        const Self = @This();

        /// densely packed values array
        dense: [CAPACITY]V = undefined,
        /// spare lookup array
        sparse: [CAPACITY]?I = [_]?I{null} ** CAPACITY,
        /// number of elements
        n: I = 0,

        pub fn init(capacity: u32, allocator: std.mem.Allocator) Self {
            _ = capacity;
            _ = allocator;

            return Self{};
        }

        pub fn deinit(self: Self) void {
            _ = self;
        }

        /// insert a value into the set
        pub fn insert(self: *Self, v: V) !void {
            if (v >= CAPACITY) return error.ValueTooBig;
            if (self.n >= CAPACITY) return error.SetFull;

            self.dense[self.n] = v;
            self.sparse[v] = self.n;

            self.n += 1;
        }

        /// remove a value from the set
        pub fn remove(self: *Self, v: V) void {
            if (v >= CAPACITY) return error.ValueTooBig;

            if (self.sparse[v]) |i| {
                self.n -= 1;
                // set to null
                self.sparse[v] = null;

                // swap the value at i with the last one
                self.dense[i] = self.dense[self.n];
                self.sparse[self.dense[i]] = i;
            }
        }

        pub fn hasValue(self: Self, v: V) bool {
            if (v >= CAPACITY) return null;
            return self.sparse[v] != null;
        }
    };
}

test "init" {
    // or should these be a handle type??
    const Index = u32;
    const Item = usize;
    const Set = SparseSet(Index, Item);
    const capacity = 10;
    var s: Set = Set.init(capacity, std.testing.allocator);
    defer s.deinit();

    try testing.expect(s.sparse[7] == null);

    try s.insert(7);
    try testing.expect(s.sparse[7] == @as(Index, 0));
    try testing.expect(s.dense[0] == @as(Index, 7));

    try s.insert(13);
    try testing.expect(s.sparse[13] == @as(Index, 1));
    try testing.expect(s.dense[1] == @as(Index, 13));
}
