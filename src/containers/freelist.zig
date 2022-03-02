const std = @import("std");
const expect = std.testing.expect;
const Allocator = std.mem.Allocator;
/// areana allocated free list
pub fn FreeList(
    comptime T: type,
) type {
    // TODO: assert that T is of greater or equal alignment
    if (@sizeOf(T) < @sizeOf(u32)) @compileError("T must be at least as big as number");
    return struct {
        /// union type to store either the next free i
        const U = extern union {
            item: T,
            next: u32,
        };

        const Self = @This();

        /// underlying storage
        /// head is the first element
        mem: []U,

        allocator: Allocator,

        /// initialize with storage
        pub fn init(allocator: Allocator, size: usize) !Self {
            var self = Self{
                .allocator = allocator,
                .mem = try allocator.alloc(U, size),
            };
            for (self.mem) |*u| {
                u.* = .{ .next = 0 };
            }
            // set head
            self.mem[0] = .{ .next = 1 };
            return self;
        }

        pub fn alloc(self: *Self) !*T {
            var head_ptr = &self.mem[0];
            // TODO: bounds checking and stuff
            var ptr = &self.mem[head_ptr.next];
            head_ptr.*.next = ptr.next;
            ptr.* = .{ .item = undefined };
            return &ptr.item;
        }

        pub fn free(self: *Self, item_ptr: *T) void {
            // does this pointer exist?
            const ptr = @ptrCast(*U, item_ptr);
            // set the item
            ptr.* = .{ .next = self.mem[0].next };
            // TOOD: get index from pointer?
            self.mem[0].next = 0;
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.mem);
        }
    };
}

test "init" {
    const foo = struct {
        x: u64 = 0,
        y: u32 = 0,
    };
    const FooList = FreeList(foo);

    var fl = try FooList.init(std.testing.allocator, 100);
    defer fl.deinit();

    try expect(@sizeOf(FooList.U) == @sizeOf(foo));
}

test "addressing" {
    const foo = struct {
        x: u64 = 0,
    };
    const FooList = FreeList(foo);

    var fl = try FooList.init(std.testing.allocator, 100);
    defer fl.deinit();
    const p = try fl.alloc();
    try expect(@ptrToInt(p) == @ptrToInt(&fl.mem[1]));
}
