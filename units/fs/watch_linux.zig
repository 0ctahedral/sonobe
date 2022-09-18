const std = @import("std");
const Handle = @import("utils").Handle;
const FreeList = @import("containers").FreeList;
const os = std.os;
const sys = std.os.linux;
const Allocator = std.mem.Allocator;

/// api for for file system watching
const Self = @This();

const MAX_WATCHES = 64;

const WATCH_FLAGS = sys.IN.ALL_EVENTS;

/// Data about the file we are watching
const FileWatch = struct {
    /// inotify file descriptor
    wd: i32,
    /// path to the file we are watching
    path: []const u8,
    /// has this file been modified
    modified: bool = false,
};

/// file descriptor for the watcher
wd: i32,

running: bool = false,

watches: FreeList(FileWatch),

thread: std.Thread = undefined,

pub fn init(allocator: Allocator) !Self {
    // const flags: u32 = os.linux.IN.NONBLOCK | os.linux.IN.CLOEXEC;
    const flags: u32 = 0;
    var self = Self{
        // open the inotify file
        .wd = try os.inotify_init1(flags),
        .watches = try FreeList(FileWatch).init(allocator, MAX_WATCHES),
    };

    return self;
}

pub fn deinit(self: *Self) void {
    self.watches.deinit();
    os.close(self.wd);
}

pub fn start(self: *Self) !void {
    if (self.running) return;
    self.running = true;
    self.thread = try std.Thread.spawn(.{}, loop, .{self});
}

pub fn stop(self: *Self) void {
    if (!self.running) return;
    self.running = false;
    self.thread.join();
}

pub fn addFile(self: *Self, path: []const u8) !Handle(.File) {
    const wd = try os.inotify_add_watch(self.wd, path, WATCH_FLAGS);
    const id = try self.watches.allocIndex();

    self.watches.set(id, .{
        .wd = wd,
        .path = path,
    });

    return Handle(.File){
        .id = @intCast(u32, id),
    };
}

/// checks if a file is changed
/// if it is then return true and reset file
pub fn modified(self: *Self, handle: Handle(.File)) bool {
    var fw = self.watches.get(handle.id);
    return @atomicRmw(bool, &fw.modified, .Xchg, false, .Acquire);
}

/// fills the handles slice with the modified handles
pub fn getModified(self: *Self, handles: []Handle(.File)) usize {
    var iter = self.watches.iter();
    var idx: usize = 0;
    while (iter.next()) |fw| {
        const handle = Handle(.File){
            .id = self.watches.getIndex(fw),
        };
        if (self.modified(handle)) {
            handles[idx] = handle;

            if (handles.len == idx) {
                return idx;
            }

            idx += 1;
        }
    }

    return idx;
}

/// the main loop of the watcher
pub fn loop(self: *Self) !void {
    var event_buf: [4096]u8 align(@alignOf(os.linux.inotify_event)) = undefined;

    // big ol buffer for reading events
    while (self.running) {

        // blocks for one second, then does the loop again
        if ((try os.poll(&[_]os.pollfd{.{
            .fd = self.wd,
            .events = sys.POLL.IN,
            .revents = 0,
        }}, std.time.ms_per_s)) == 0) {
            continue;
        }

        const bytes_read = os.read(self.wd, &event_buf) catch |err| switch (err) {
            error.WouldBlock => {
                continue;
            },
            else => return err,
        };
        // TODO: multiple events
        var ptr: [*]u8 = &event_buf;
        var end_ptr: [*]u8 = ptr + bytes_read;

        while (@ptrToInt(ptr) < @ptrToInt(end_ptr)) {
            const ev = @ptrCast(*const os.linux.inotify_event, ptr);
            ptr = @alignCast(@alignOf(os.linux.inotify_event), ptr + @sizeOf(os.linux.inotify_event) + ev.len);
            const fw = self.getFileWatch(ev.wd) orelse {
                debugEventMask(ev.mask);
                continue;
            };
            if (ev.mask & sys.IN.MODIFY != 0 or ev.mask & sys.IN.ATTRIB != 0) {
                @atomicStore(bool, &fw.*.modified, true, .Release);
            }

            if (ev.mask & sys.IN.IGNORED != 0) {
                // remove from notify
                const wd = try os.inotify_add_watch(self.wd, fw.path, WATCH_FLAGS);
                fw.*.wd = wd;
            }
        }
    }
}

fn getFileWatch(self: *Self, wd: i32) ?*FileWatch {
    // TODO: this kinda sucks since it is o(n) every event
    // make a spare set type that fixes this
    // This makes sense too since we are getting the file more often
    // than the handle so this should be best case for both
    var iter = self.watches.iter();
    while (iter.next()) |fw| {
        if (fw.wd == wd) {
            return fw;
        }
    }
    return null;
}

fn debugEventMask(mask: u32) void {
    inline for (@typeInfo(sys.IN).Struct.decls) |f| {
        const m = @field(sys.IN, f.name);
        if (m & mask != 0 and m != sys.IN.ALL_EVENTS) {
            std.debug.print("file {s}\n", .{f.name});
        }
    }
}
