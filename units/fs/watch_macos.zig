const std = @import("std");
const utils = @import("utils");
const Handle = utils.Handle;
const os = std.os;
const sys = std.os.system;
const Allocator = std.mem.Allocator;

const Data = struct {
    path: []const u8,
    /// has this file changed?
    changed: std.atomic.Atomic(bool) = std.atomic.Atomic(bool).init(false),
    fd: i32 = -1,
};

const Self = @This();
const vnode_events: u32 = sys.NOTE_DELETE | sys.NOTE_ATTRIB | sys.NOTE_LINK | sys.NOTE_REVOKE;

kq: i32 = -1,
allocator: Allocator,
datas: std.ArrayList(Data),

mutex: std.Thread.Mutex = .{},

thread: std.Thread = undefined,

running: bool = false,

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

    return Handle(.File){ .id = @intCast(u32, self.datas.items.len - 1) };
}

/// checks if a file is changed
/// if it is then return true and reset file
pub fn modified(self: *Self, handle: Handle(.File)) bool {
    var d = &self.datas.items[handle.id];
    const changed = d.changed.load(.Unordered);
    if (changed) {
        d.changed.store(false, .Unordered);
    }

    return changed;
}

pub fn getModified(self: *Self, handles: []Handle(.File)) usize {
    var idx: usize = 0;
    for (self.datas.items) |_, i| {
        const handle = Handle(.File){
            .id = @intCast(u32, i),
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

fn processEvents(self: *Self, events: []os.Kevent) !void {
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
            log.warn("unknown event: {}\n", .{ev});
        }
    }
}

pub fn loop(self: *Self) !void {

    // TOOD: these can be stacks
    // events to process
    var events = try std.ArrayList(os.Kevent).initCapacity(self.allocator, 10);
    // changes to monitor
    var changes = try std.ArrayList(os.Kevent).initCapacity(self.allocator, 10);

    while (self.running) {
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

    events.deinit();
    changes.deinit();
}
