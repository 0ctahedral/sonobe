const std = @import("std");
const Allocator = std.mem.Allocator;

/// Caches types and stuff
pub fn Cache(
    /// info type for hash lookup and type creation
    comptime I: type,
    /// type we are caching
    comptime T: type,
    /// context for hashing
    comptime HashContext: ?type,
    /// creation and destroy functions
    comptime Context: type
) type {
    const HashMapType = if (HashContext) |ctx|
        std.ArrayHashMap(I, T, ctx, false) else
        std.AutoArrayHashMap(I, T);

    return struct {
        map: HashMapType = undefined,

        const Self = @This();

        /// create a new cache
        pub fn init(self: *Self, alloc: Allocator) void {
            self.map = HashMapType.init(alloc);
        }

        /// get a T and create it if it doesn't exist
        pub fn request(self: *Self, args: anytype) !T {
            const info = args[0];
            if (self.map.get(info)) |cached| {
                return cached;
            }

            // otherwise create it and add to map
            const t = try @call(.{}, Context.create, args);
            try self.map.putNoClobber(info, t);
            return t;
        }

        /// clears cache and maintains capacity
        pub fn clear(self: *Self) void {
            for (self.map.values()) |v| {
               Context.destroy(v); 
            }
            self.map.clearRetainingCapacity();
        }

        pub fn deinit(self: *Self) void {
            for (self.map.values()) |v| {
               Context.destroy(v); 
            }
            self.map.deinit();
        }
    };
}
