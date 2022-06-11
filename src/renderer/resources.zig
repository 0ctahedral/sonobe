const std = @import("std");
const Allocator = std.mem.Allocator;

/// opaque type 
pub const Handle = enum(u32) {
    null_handle = 0,
};

// const Buffer = struct {
//     offset: u32 = 0,
//     size: u32 = 0,
// };
//
// var allocator: Allocator = undefined;
//
// var index: usize = 0;
//
// var buffers: std.ArrayList(Buffer) = undefined;
//
// pub fn init(alloc: Allocator) !void {
//     allocator = alloc;
//     buffers = std.ArrayList(Buffer).initCapacity(allocator, 10);
//
//     // allocate a pool from the backend
// }
//
// pub fn createBuffer() Handle {
//     const handle = Handle{index};
//
//     // sub allocate
//
//     buffers[handle] = Buffer{};
//
//     index += 1;
//     return handle;
// }
