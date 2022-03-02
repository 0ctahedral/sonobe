const std = @import("std");
const expect = std.testing.expect;
const Allocator = std.mem.Allocator;
/// areana allocated free list
pub fn FreeList(
    comptime T: type,
) type {

    // union type to store either the next free index or the itme
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

        allocator: Allocator,

        /// initialize with storage
        pub fn init(allocator: Allocator, size: usize) !Self {
            var self = Self{
                .allocator = allocator,
                .mem = try allocator.alloc(Item, size),
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
            const slot = self.mem[0].next;
            self.mem[0].next = self.mem[@as(usize, slot)].next;
            // if the head is pointing to itself then the buffer is full
            if (slot > 0) {
                self.mem[slot] = .{ .item = undefined };
                return &self.mem[slot].item;
            }

            // TODO: resize?
            return error.OutOfMemory;
        }

        pub inline fn free(self: *Self, item_ptr: *T) void {
            self.freeAny(item_ptr);
        }

        pub fn freeAny(self: *Self, item_ptr: *anyopaque) void {
            const index = (@ptrToInt(item_ptr) - @ptrToInt(self.mem.ptr)) / @sizeOf(Item);
            // insert at the front of the list
            self.mem[index] = .{ .next = self.mem[0].next };
            self.mem[0].next = @intCast(u32, index);
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.mem);
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
