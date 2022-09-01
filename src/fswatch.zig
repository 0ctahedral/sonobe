const std = @import("std");
const Handle = @import("handle.zig").Handle;
const os = std.os;
const sys = std.os.system;
const Allocator = std.mem.Allocator;

const Data = struct {
    path: []const u8,
    /// has this file changed?
    changed: std.atomic.Atomic(bool) = std.atomic.Atomic(bool).init(false),
    fd: i32 = -1,
};

pub const KQWatcher = struct {
    const Self = @This();
    const vnode_events: u32 = sys.NOTE_DELETE | sys.NOTE_ATTRIB | sys.NOTE_LINK | sys.NOTE_REVOKE;

    kq: i32 = -1,
    allocator: Allocator,
    datas: std.ArrayList(Data),

    mutex: std.Thread.Mutex = .{},

    pub fn init(allocator: Allocator) !Self {
        var self = Self{
            .kq = try os.kqueue(),
            .allocator = allocator,
            .datas = std.ArrayList(Data).init(allocator),
        };

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.datas.deinit();
        os.close(self.kq);
    }

    pub fn addFile(self: *Self, path: []const u8) !Handle(.File) {
        self.mutex.lock();
        defer self.mutex.unlock();

        var d = Data{
            .path = path,
            .fd = try os.open(path, os.O.EVTONLY, 0),
        };

        try self.datas.append(d);

        std.debug.print("adding file: {s}\n", .{path});

        return Handle(.File){ .id = @intCast(u32, self.datas.items.len - 1) };
    }

    /// checks if a file is changed
    /// if it is then return true and reset file
    pub fn checkChanged(self: *Self, handle: Handle(.File)) bool {
        var d = &self.datas.items[handle.id];
        const changed = d.changed.load(.Unordered);
        if (changed) {
            d.changed.store(false, .Unordered);
        }

        return changed;
    }

    pub fn processEvents(self: *Self, events: []os.Kevent) !void {
        for (events) |ev| {
            const idx: usize = @intCast(usize, ev.udata);
            self.mutex.lock();
            defer self.mutex.unlock();
            var d = &self.datas.items[idx];
            if (ev.fflags & sys.NOTE_ATTRIB != 0) {
                d.changed.store(true, .Unordered);
            } else if (ev.fflags & (sys.NOTE_DELETE | sys.NOTE_LINK) != 0) {
                os.close(d.fd);
                d.*.fd = try os.open(d.path, os.O.EVTONLY, 0);
            } else {
                std.debug.print("unknown event: {}\n", .{ev});
            }
        }
    }

    pub fn run(self: *Self) !void {

        // TOOD: these can be stacks
        // events to process
        var events = try std.ArrayList(os.Kevent).initCapacity(self.allocator, 10);
        // changes to monitor
        var changes = try std.ArrayList(os.Kevent).initCapacity(self.allocator, 10);

        while (true) {
            {
                self.mutex.lock();
                defer self.mutex.unlock();

                // add changes to our list
                for (self.datas.items) |w, i| {
                    try changes.append(.{
                        .ident = @intCast(usize, w.fd),
                        .filter = sys.EVFILT_VNODE,
                        .flags = sys.EV_ADD | sys.EV_ENABLE | sys.EV_CLEAR | sys.EV_ONESHOT,
                        .fflags = vnode_events,
                        .data = 0,
                        .udata = i,
                    });
                    try events.append(undefined);
                }
            }

            const count = try os.kevent(
                self.kq,
                changes.items,
                events.items,
                &std.os.timespec{
                    .tv_sec = 1,
                    .tv_nsec = 0,
                },
            );

            if (count > 0) {
                try self.processEvents(events.items[0..count]);
            }

            // clear the events and changes queues
            events.clearRetainingCapacity();
            changes.clearRetainingCapacity();
        }
    }
};

fn changedloop(kqw: *KQWatcher, handles: []Handle(.File), paths: [][]const u8) void {
    while (true) {
        std.time.sleep(std.time.ns_per_s);
        for (handles) |h, i| {
            if (kqw.checkChanged(h)) {
                std.debug.print("{s} changed!\n", .{paths[i]});
            }
        }
    }
}

test "interactive" {
    const allocator = std.testing.allocator;
    // this runs in own thread
    // given a file to watch and a counter, we can reset the counter when the file changes, remove it from the freelist
    // thus a job waiting on this thread will continue
    // and the job itself can add the file
    var kqw = try KQWatcher.init(allocator);
    defer kqw.deinit();

    var paths = [_][]const u8{ "test/file.txt", "test/bloop.txt", "test/bop.txt" };
    var file_handles: [paths.len]Handle(.File) = undefined;

    var kthread = try std.Thread.spawn(.{}, KQWatcher.run, .{&kqw});
    for (paths) |p, i| {
        file_handles[i] = try kqw.addFile(p);
    }

    var cthread = try std.Thread.spawn(.{}, changedloop, .{ &kqw, &file_handles, &paths });

    cthread.join();
    kthread.join();
}
