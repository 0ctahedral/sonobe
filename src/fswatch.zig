const std = @import("std");
const FreeList = @import("containers.zig").FreeList;
const jobs = @import("jobs.zig");
const Counter = jobs.Counter;
const os = std.os;
const sys = std.os.system;
const Allocator = std.mem.Allocator;

const Data = struct {
    path: []const u8,
    fd: i32 = -1,
    counter: *Counter,
};

pub const KQWatcher = struct {
    const Self = @This();
    const vnode_events: u32 = sys.NOTE_DELETE | sys.NOTE_ATTRIB | sys.NOTE_LINK | sys.NOTE_REVOKE;

    kq: i32 = -1,
    fl: FreeList(Data),
    allocator: Allocator,

    mutex: std.Thread.Mutex = .{},

    pub fn init(allocator: Allocator) !Self {
        var self = Self{
            .kq = try os.kqueue(),
            .fl = try FreeList(Data).init(allocator, 10),
            .allocator = allocator,
        };

        return self;
    }

    pub fn deinit(self: *Self) void {
        os.close(self.kq);
        self.fl.deinit();
    }

    pub fn addFile(self: *Self, path: []const u8, counter: *Counter) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var d = Data{
            .path = path,
            .counter = counter,
        };
        d.fd = try os.open(path, os.O.EVTONLY, 0);

        const handle = try self.fl.allocIndex();
        self.fl.set(handle, d);
        std.debug.print("adding file: {s}\n", .{path});
    }

    pub fn processEvents(self: *Self, events: []os.Kevent) !void {
        for (events) |ev| {
            const handle = @truncate(u32, ev.udata);
            var d = self.fl.get(handle);
            if (ev.fflags & sys.NOTE_ATTRIB != 0) {
                d.counter.dec();
            } else if (ev.fflags & (sys.NOTE_DELETE | sys.NOTE_LINK) != 0) {
                std.debug.print("reset: {s}\n", .{d.path});
                os.close(d.fd);
                d.*.fd = try os.open(d.path, os.O.EVTONLY, 0);
            } else {
                std.debug.print("unknown event: {}\n", .{ev});
            }
        }
    }

    pub fn run(self: *Self) !void {

        // events to process
        var events = try std.ArrayList(os.Kevent).initCapacity(self.allocator, 10);
        // changes to monitor
        var changes = try std.ArrayList(os.Kevent).initCapacity(self.allocator, 10);

        while (true) {
            // TODO: fix this awful mutex use
            self.mutex.lock();
            defer self.mutex.unlock();
            // get events
            var itr = self.fl.iter();

            // add changes to our list
            while (itr.next()) |w| {
                try changes.append(.{
                    .ident = @intCast(usize, w.fd),
                    .filter = sys.EVFILT_VNODE,
                    .flags = sys.EV_ADD | sys.EV_ENABLE | sys.EV_CLEAR | sys.EV_ONESHOT,
                    .fflags = vnode_events,
                    .data = 0,
                    .udata = self.fl.getIndex(w),
                });
                try events.append(undefined);
            }

            const count = try os.kevent(self.kq, changes.items, events.items, &std.os.timespec{
                .tv_sec = 1,
                .tv_nsec = 0,
            });

            if (count > 0) {
                try self.processEvents(events.items[0..count]);
            }

            // clear the events and changes queues
            events.clearRetainingCapacity();
            changes.clearRetainingCapacity();
        }
    }
};

test "test" {
    const allocator = std.testing.allocator;
    // this runs in own thread
    // given a file to watch and a counter, we can reset the counter when the file changes, remove it from the freelist
    // thus a job waiting on this thread will continue
    // and the job itself can add the file
    var kqw = try KQWatcher.init(allocator);
    defer kqw.deinit();

    var files = [_][]const u8{ "test/file.txt", "test/bloop.txt", "test/bop.txt" };

    var thread = try std.Thread.spawn(.{}, KQWatcher.run, .{&kqw});
    for (files) |p| {
        try kqw.addFile(p);
    }
    thread.join();
}

fn readOut(file: std.fs.File, c: *Counter, allocator: std.mem.Allocator) void {
    // wait for c to equal zero
    jobs.wait(c, 0);

    // read contents of file and print them
    const reader = file.reader();
    var buf = reader.readAllAlloc(allocator, 1024) catch {
        std.debug.print("could not read\n", .{});
        return;
    };
    defer allocator.free(buf);
    std.debug.print("contents: {s}\n", .{buf});
}

fn printDone(c: *Counter) void {
    jobs.wait(c, 0);
    std.debug.print("woohoo\n", .{});
}
const test_tmp_dir = "tmp_test";
test "wait for file change" {
    const allocator = std.testing.allocator;
    try jobs.init(allocator);
    defer jobs.deinit();

    var kqw = try KQWatcher.init(allocator);
    defer kqw.deinit();

    // create directory and open file
    try std.fs.cwd().makePath(test_tmp_dir);
    defer std.fs.cwd().deleteTree(test_tmp_dir) catch {};

    const file_path = try std.fs.path.join(allocator, &[_][]const u8{ test_tmp_dir, "file.txt" });
    defer allocator.free(file_path);

    const contents =
        \\line 1
        \\line 2
    ;
    const contents2 =
        \\lorem
        \\ipsum
    ;
    try std.fs.cwd().writeFile(file_path, contents);
    // open the file

    var file_c = Counter{};
    var thread = try std.Thread.spawn(.{}, KQWatcher.run, .{&kqw});
    try kqw.addFile(file_path, &file_c);

    var i: u8 = 0;
    while (i < 3) : (i += 1) {
        var done = Counter{};

        // jtry jobs.run(readOut, .{ file, &file_c, allocator }, &done);
        try jobs.run(printDone, .{&file_c}, &done);

        try std.testing.expect(file_c.val() == 1);
        try std.fs.cwd().writeFile(file_path, contents2);

        std.time.sleep(std.time.ns_per_s);

        try std.testing.expect(file_c.val() == 0);
        try std.testing.expect(done.val() == 0);
    }

    thread.join();
}
