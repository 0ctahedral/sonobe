const std = @import("std");
const expect = std.testing.expect;
const Allocator = std.mem.Allocator;

pub fn FreeList(
    comptime T: type,
) type {

    // union type to store either the next free index or the item
    const item_t = extern union {
        item: T,
        next: u32,
    };

    // TODO: assert that T is of greater or equal alignment
    if (@sizeOf(T) < @sizeOf(item_t)) @compileError("T must be at least as big as item storage type");

    return struct {
        const Item = item_t;

        /// type of index elements
        const Index = u32;

        const Self = @This();

        /// underlying storage
        /// head is the first element
        mem: []Item,

        allocator: ?Allocator,

        /// initialize with storage
        pub fn init(allocator: Allocator, size: usize) !Self {
            var self = Self{
                .allocator = allocator,
                .mem = try allocator.alloc(Item, size),
            };
            self.reset();
            return self;
        }

        /// resets the whole command pool
        pub fn reset(self: *Self) void {
            for (self.mem) |*u, i| {
                u.* = .{ .next = @intCast(u32, i) + 1 };
            }
            // set head
            self.mem[0] = .{ .next = 1 };
            self.mem[self.mem.len - 1] = .{ .next = 0 };
        }

        // TODO: this should be default
        pub fn initArena(mem: []T) !Self {
            const size = mem.len;

            var ptr = @ptrCast([*]Item, mem.ptr);

            var self = Self{
                .allocator = null,
                .mem = ptr[0..size],
            };
            // TODO: is this necessary?
            for (self.mem) |*u, i| {
                u.* = .{ .next = @intCast(u32, i) + 1 };
            }
            // set head
            self.mem[0] = .{ .next = 1 };
            self.mem[size - 1] = .{ .next = 0 };
            return self;
        }

        pub inline fn allocAny(self: *Self) !*anyopaque {
            @ptrCast(*anyopaque, self.alloc());
        }

        pub fn alloc(self: *Self) !*T {
            const slot = try self.allocIndex();
            return &self.mem[slot].item;
        }

        pub fn allocIndex(self: *Self) !Index {
            const slot = self.mem[0].next;
            self.mem[0].next = self.mem[@as(usize, slot)].next;
            // if the head is pointing to itself then the buffer is full
            if (slot > 0) {
                self.mem[slot] = .{ .item = undefined };
                return slot;
            }

            // TODO: resize?
            return error.OutOfMemory;
        }

        pub inline fn free(self: *Self, item_ptr: *T) void {
            self.freeAny(item_ptr);
        }

        pub fn freeAny(self: *Self, item_ptr: *anyopaque) void {
            const index = (@ptrToInt(item_ptr) - @ptrToInt(self.mem.ptr)) / @sizeOf(Item);
            self.freeIndex(@intCast(u32, index));
        }

        pub fn freeIndex(self: *Self, idx: Index) void {
            const index = @as(usize, idx);
            // insert at the front of the list
            self.mem[index] = .{ .next = self.mem[0].next };
            self.mem[0].next = @intCast(u32, index);
        }

        pub fn set(self: *Self, idx: Index, val: T) void {
            self.mem[@intCast(usize, idx)] = .{ .item = val };
        }

        pub fn get(self: *Self, idx: Index) *T {
            return &self.mem[@intCast(usize, idx)].item;
        }

        pub inline fn getIndex(self: Self, ptr: *T) Index {
            const index = (@ptrToInt(ptr) - @ptrToInt(self.mem.ptr)) / @sizeOf(Item);
            return @intCast(u32, index);
        }

        pub fn deinit(self: *Self) void {
            if (self.allocator) |a| {
                a.free(self.mem);
            }
        }

        const Iter = struct {
            fl: *Self,
            next_free: u32,
            i: usize,

            pub fn next(self: *Iter) ?*T {
                while (self.next_free == self.i) {
                    self.next_free = self.fl.mem[self.i].next;
                    if (self.next_free == 0) {
                        return null;
                    }
                    self.i += 1;
                }

                var ret: *T = &self.fl.mem[self.i].item;
                self.i += 1;

                return ret;
            }
        };

        pub fn iter(self: *Self) Iter {
            return Iter{
                .fl = self,
                .next_free = self.mem[0].next,
                .i = 1,
            };
        }
    };
}
const foo = struct {
    x: u64 = 0,
    y: u32 = 0,
};

test "init" {
    const FooList = FreeList(foo);

    var fl = try FooList.init(std.testing.allocator, 100);
    defer fl.deinit();

    try expect(@sizeOf(FooList.Item) == @sizeOf(foo));
}

test "init arena" {
    const FooList = FreeList(foo);

    var data = try std.testing.allocator.alloc(foo, 100);
    defer std.testing.allocator.free(data);

    var fl = try FooList.initArena(data);
    defer fl.deinit();

    try expect(@sizeOf(FooList.Item) == @sizeOf(foo));
    try expect(fl.mem.len == 100);
}

test "addressing" {
    const FooList = FreeList(foo);
    var fl = try FooList.init(std.testing.allocator, 100);
    defer fl.deinit();
    const p1 = try fl.alloc();
    try expect(@ptrToInt(p1) == @ptrToInt(&fl.mem[1]));
    const p2 = try fl.alloc();
    try expect(@ptrToInt(p2) == @ptrToInt(&fl.mem[2]));

    fl.free(p2);
    try expect(fl.mem[0].next == 2);
}

test "exceed memory" {
    const FooList = FreeList(foo);
    var fl = try FooList.init(std.testing.allocator, 100);
    defer fl.deinit();

    var i: u8 = 0;
    while (i < 99) : (i += 1) {
        _ = try fl.alloc();
    }
    try std.testing.expectError(error.OutOfMemory, fl.alloc());
}

test "array type" {
    const StackList = FreeList([400]u8);
    var fl = try StackList.init(std.testing.allocator, 10);
    defer fl.deinit();
}

test "iter" {
    const FooList = FreeList(foo);
    var fl = try FooList.init(std.testing.allocator, 100);
    defer fl.deinit();
    const p1 = try fl.alloc();
    const p2 = try fl.alloc();
    const p3 = try fl.alloc();

    fl.free(p2);

    var iter = fl.iter();

    const f1 = iter.next();
    try expect(@ptrToInt(f1) == @ptrToInt(p1));
    const f3 = iter.next();
    try expect(@ptrToInt(f3) == @ptrToInt(p3));
    try expect(iter.next() == null);
}
