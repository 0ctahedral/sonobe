//! hashing fuction and hash map setup
const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

/// string hashing function
pub fn hashString(str: []const u8) u32 {
    // hashing prime
    var k: u32 = 5381;

    for (str) |c| {
        k = ((k << 5) +% k) + c;
    }

    return k;
}

test "hash string" {
    const str1 = "hello";
    const str2 = "world";

    const h1 = hashString(str1);
    const h2 = hashString(str2);

    try std.testing.expect(h1 != h2);
    try std.testing.expect(h1 == hashString(str1));
    try std.testing.expect(h2 == hashString(str2));
    try std.testing.expect(h1 == hashString("hello"));
    try std.testing.expect(h2 == hashString("world"));
}

pub const Hash = struct {
    keys: []usize,
    inds: []usize,
    capacity: usize,
    last: usize,

    const Self = @This();
    const UNUSED = std.math.maxInt(usize);

    /// init using an allocator
    pub fn init(allocator: Allocator, capacity: usize) !Self {
        var ret: Self = undefined;

        ret.last = 0;
        ret.capacity = capacity;
        ret.keys = try allocator.alloc(usize, capacity);
        ret.inds = try allocator.alloc(usize, capacity);
        // zero it all out
        {
            var i: usize = 0;
            while (i < capacity) : (i += 1) {
                ret.keys[i] = UNUSED;
                ret.inds[i] = 0;
            }
        }
        return ret;
    }

    /// init using a block
    pub fn blockInit(block: []const u8) !Self {
        var ret: Self = undefined;

        const capacity = block.len / (@sizeOf(usize) * 2);

        ret.last = 0;
        ret.capacity = capacity;
        //ret.keys = try allocator.alloc(usize, capacity);
        //ret.inds = try allocator.alloc(usize, capacity);
        // zero it all out
        //{
        //    var i: usize = 0;
        //    while (i < capacity) : (i += 1) {
        //        ret.keys[i] = UNUSED;
        //        ret.inds[i] = 0;
        //    }
        //}
        return ret;
    }

    pub fn deinit(self: Self, allocator: Allocator) void {
        allocator.free(self.keys);
        allocator.free(self.inds);
    }

    /// add a key index pair to the hash
    pub fn add(self: *Self, key: usize, ind: usize) !void {
        if (self.getKeyIdx(key)) |i| {
            _ = i;
            return error.KeyCollision;
        }

        if (self.last == self.capacity) {
            return error.CapacityExceeded;
        }

        self.keys[self.last] = key;
        self.inds[self.last] = ind;
        self.last += 1;
    }

    fn getKeyIdx(self: Self, key: usize) ?usize {
        var i: usize = 0;
        while (i < self.capacity) : (i += 1) {
            if (self.keys[i] == key) {
                return i;
            }
        }

        return null;
    }

    /// returns the index stored with the key, if it exist,
    /// otherwise returns nothing
    pub fn get(self: Self, key: usize) ?usize {
        if (self.getKeyIdx(key)) |i| {
            return self.inds[i];
        }
        return null;
    }

    /// sets the value of a key if it exists
    /// otherwise does nothing
    pub fn set(self: Self, key: usize, val: usize) void {
        if (self.getKeyIdx(key)) |i| {
            self.inds[i] = val;
        }
    }
};

test "init" {
    const alloc = testing.allocator;
    var hm = try Hash.init(alloc, 100);
    defer hm.deinit(alloc);
}

test "add" {
    const alloc = testing.allocator;
    var hm = try Hash.init(alloc, 100);
    defer hm.deinit(alloc);

    try hm.add(10, 5);
    try testing.expect(hm.keys[0] == 10);
    try testing.expect(hm.inds[0] == 5);

    try testing.expectError(error.KeyCollision, hm.add(10, 5));
}

test "get" {
    const alloc = testing.allocator;
    var hm = try Hash.init(alloc, 100);
    defer hm.deinit(alloc);

    try hm.add(10, 5);
    try testing.expect(hm.keys[0] == 10);
    try testing.expect(hm.inds[0] == 5);

    try testing.expect(hm.get(10).? == 5);
    try testing.expect(hm.get(34592) == null);
}

test "get" {
    const alloc = testing.allocator;
    var hm = try Hash.init(alloc, 100);
    defer hm.deinit(alloc);

    try hm.add(10, 5);
    try testing.expect(hm.keys[0] == 10);
    try testing.expect(hm.inds[0] == 5);

    hm.set(10, 22);
    try testing.expect(hm.keys[0] == 10);
    try testing.expect(hm.inds[0] == 22);
}

test "string hash map" {
    const str1 = "hello";
    const str2 = "world";

    const alloc = testing.allocator;
    var hm = try Hash.init(alloc, 100);
    defer hm.deinit(alloc);

    try hm.add(hashString(str1), 1);
    try hm.add(hashString(str2), 2);

    try testing.expect(hm.get(hashString("hello")).? == 1);
    try testing.expect(hm.get(hashString("world")).? == 2);
    try testing.expect(hm.get(hashString("bloop")) == null);
}

test "block init" {
    var block: [1024]u8 = undefined;
    var hm = try Hash.blockInit(&block);
    try testing.expect(hm.capacity == 64);
}
