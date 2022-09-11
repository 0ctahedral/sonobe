const std = @import("std");
const Handle = @import("utils").Handle;
const os = std.os;
const sys = std.os.system;
const Allocator = std.mem.Allocator;

/// api for for file system watching
const Self = @This();
pub fn init(allocator: Allocator) !Self {
    _ = allocator;
    return Self{};
}

pub fn deinit(self: *Self) void {
    _ = self;
}

pub fn addFile(self: *Self, path: []const u8) !Handle(.File) {
    _ = self;
    _ = path;

    return Handle(.File){};
}

/// checks if a file is changed
/// if it is then return true and reset file
pub fn checkChanged(self: *Self, handle: Handle(.File)) bool {
    _ = self;
    _ = handle;

    return true;
}

// pub fn run(self: *Self) !void { }

