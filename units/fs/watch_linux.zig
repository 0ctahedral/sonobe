const std = @import("std");
const Handle = @import("utils").Handle;
const os = std.os;
const sys = std.os.linux;
const Allocator = std.mem.Allocator;

/// api for for file system watching
const Self = @This();

/// file descriptor for the watcher
wd: i32,

running: bool = true,

pub fn init(allocator: Allocator) !Self {
    _ = allocator;
    const flags: u32 = 0;
    return Self{
        // open the inotify file
        .wd = try os.inotify_init1(flags),
    };
}

pub fn deinit(self: *Self) void {
    self.running = false;
    os.close(self.wd);
}

pub fn addFile(self: *Self, path: []const u8) !Handle(.File) {
    // const flags: u32 = sys.IN.MODIFY;
    const flags: u32 = sys.IN.ALL_EVENTS;
    const id = try os.inotify_add_watch(self.wd, path, flags);

    return Handle(.File){
        .id = @intCast(u32, id),
    };
}

/// checks if a file is changed
/// if it is then return true and reset file
pub fn checkChanged(self: *Self, handle: Handle(.File)) bool {
    _ = self;
    _ = handle;

    return true;
}

pub fn run(self: *Self) !void {
    // big ol buffer for reading events
    while (self.running) {
        var event_buf: [4096]u8 align(@alignOf(os.linux.inotify_event)) = undefined;
        const bytes_read = os.read(self.wd, &event_buf) catch unreachable;
        // TODO: multiple events
        var ptr: [*]u8 = &event_buf;
        var end_ptr: [*]u8 = ptr + bytes_read;

        while (@ptrToInt(ptr) < @ptrToInt(end_ptr)) {
            const ev = @ptrCast(*const os.linux.inotify_event, ptr);
            std.debug.print("ev: {}\n", .{ev});

            inline for (@typeInfo(sys.IN).Struct.decls) |f| {
                // std.debug.print("field: {s} {x}\n", .{ f.name,  });
                const m = @field(sys.IN, f.name);
                if (m & ev.mask != 0) {
                    std.debug.print("file {s}\n", .{f.name});
                }
            }

            // if (ev.mask & sys.IN.MODIFY != 0) {
            //     std.debug.print("file {}: modified\n", .{
            //         ev.cookie,
            //     });
            // }

            ptr = @alignCast(@alignOf(os.linux.inotify_event), ptr + @sizeOf(os.linux.inotify_event) + ev.len);
        }
    }
}
