const std = @import("std");
const expect = std.testing.expect;
const containers = @import("containers.zig");
const RingBuffer = containers.RingBuffer;
const FreeList = containers.FreeList;

pub const Jobs = @This();
pub const num_threads = 4;
pub const stack_size = 4 * 1024;
pub const num_jobs = 120;

var global: Jobs = undefined;
pub var instance: ?*Jobs = null;

/// state of the job system
done: bool = false,

worker_threads: [num_threads]std.Thread = undefined,

/// fibers that are ready
frame_queue: RingBuffer(anyframe, num_jobs),
/// fibers that are waiting
wait_queue: RingBuffer(WaitingFrame, num_jobs),

alloc: std.mem.Allocator,

// TODO: make this thread safe
stacks: FreeList([stack_size]u8),

timer: std.time.Timer,

/// Basically a semaphore, indicates when a job dependency is done
pub const Counter = struct {
    /// value stored in this counter
    value: usize = 0,

    const Self = @This();

    pub fn inc(self: *Self) void {
        _ = @atomicRmw(usize, &self.value, .Add, 1, .SeqCst);
    }

    pub fn dec(self: *Self) void {
        _ = @atomicRmw(usize, &self.value, .Sub, 1, .SeqCst);
    }

    pub fn val(self: *Self) usize {
        return @atomicLoad(usize, &self.value, .SeqCst);
    }
};

/// a condition for resuming a waiting from
const ResumeCondition = union(enum) {
    /// waiting on a counter
    Counter: struct {
        /// counter  we must wait on
        counter: *Counter,
        /// value the counter should be at to continue execution
        value: usize = 0,
    },

    /// waiting for a timer
    Sleep: struct {
        /// time this timer was started
        start: u64,
        /// amount of time to wait
        duration: u64,
    },
};

/// A job that is waiting on a counter
const WaitingFrame = struct {
    condition: ResumeCondition,
    /// function to resume from
    frame: anyframe,
};

/// initialize the jobs subsystem
/// this creates an instance
pub fn init(allocator: std.mem.Allocator) !void {
    global = Jobs{
        .frame_queue = RingBuffer(anyframe, num_jobs).init(),
        .wait_queue = RingBuffer(WaitingFrame, num_jobs).init(),
        .alloc = allocator,
        .stacks = try FreeList([stack_size]u8).init(allocator, num_jobs),
        .timer = try std.time.Timer.start(),
    };

    for (global.worker_threads) |*t, i| {
        t.* = try std.Thread.spawn(.{}, loop, .{ &global, @intCast(u32, i) });
    }

    instance = &global;
}

/// shutdown the job subsystem
/// joins all worker threads
pub fn deinit() void {
    global.done = true;
    for (global.worker_threads) |t| {
        t.join();
    }
    global.frame_queue.clear();
    global.wait_queue.clear();
    global.stacks.deinit();
    instance = null;
}

// TODO: more complex conditions? (c < 5)
/// wait for a counter to reach a value
pub fn wait(counter: *Counter, value: usize) void {
    suspend {
        instance.?.wait_queue.push(.{
            .frame = @frame(),
            .condition = .{ .Counter = .{
                .counter = counter,
                .value = value,
            } },
        }) catch unreachable;
    }
}

/// sleep for a number of nanoseconds
pub fn sleep(ns: u64) void {
    suspend {
        instance.?.wait_queue.push(.{
            .frame = @frame(),
            .condition = .{ .Sleep = .{
                .start = instance.?.timer.read(),
                .duration = ns,
            } },
        }) catch unreachable;
    }
}

pub fn run(comptime func: anytype, args: anytype, counter: ?*Counter) !void {
    const Wrapper = struct {
        const Args = @TypeOf(args);
        fn run(fnargs: Args, c: ?*Counter) void {
            // yeild to put this on the queue
            suspend {
                if (c != null) {
                    c.?.inc();
                }
                instance.?.frame_queue.push(@frame()) catch unreachable;
            }

            @call(.{}, func, fnargs);
            // cleanup
            suspend {
                if (c != null) {
                    c.?.dec();
                }
                instance.?.stacks.freeAny(@frame());
            }
        }
    };

    var run_frame = @ptrCast(*@Frame(Wrapper.run), @alignCast(16, try instance.?.stacks.alloc()));
    run_frame.* = async Wrapper.run(args, counter);
}

fn loop(self: *Jobs, thread_number: u32) void {
    _ = thread_number;
    while (!self.done) {
        var tmp_queue = RingBuffer(WaitingFrame, 32).init();

        while (self.wait_queue.pop()) |w| {
            // pop and check if the condition is met
            // if it is then we can run it
            // otherwise add to back of queue

            switch (w.condition) {
                .Counter => |c| {
                    if (c.counter.val() == c.value) {
                        self.frame_queue.push(w.frame) catch unreachable;
                        continue;
                    }
                },
                .Sleep => |s| {
                    if (self.timer.read() >= s.start + s.duration) {
                        self.frame_queue.push(w.frame) catch unreachable;
                        continue;
                    }
                },
            }

            // condition not met, push to the temporary queue
            tmp_queue.push(w) catch {
                instance.?.wait_queue.push(w) catch unreachable;
                break;
            };
        }

        // put them back
        while (tmp_queue.pop()) |j| {
            self.wait_queue.push(j) catch unreachable;
        }

        // resume from a frame
        while (self.frame_queue.pop()) |frame| {
            resume frame;
        }
    }
}

test "no funcs called" {
    try init(std.testing.allocator);
    defer deinit();

    std.time.sleep(std.time.ns_per_s / 10);
}

// TESTS AND STUFF
fn onesuspend(a: *u32, c: *Counter) void {
    a.* += 1;
    // std.debug.print("added 1\n", .{});
    wait(c, 0);
    a.* += 1;
    // std.debug.print("added 1 again\n", .{});
}

test "function with single suspend" {
    var a: u32 = 0;
    var wait_c: Counter = Counter{ .value = 1 };

    try init(std.testing.allocator);
    defer deinit();

    var job_c = Counter{};

    try run(onesuspend, .{ &a, &wait_c }, &job_c);

    try expect(a == 0);
    try expect(job_c.value == 1);

    std.time.sleep(std.time.ns_per_s / 10);

    try expect(a == 1);
    try expect(job_c.value == 1);

    wait_c.dec();

    std.time.sleep(std.time.ns_per_s / 10);

    try expect(a == 2);
    try expect(job_c.value == 0);
}

fn spawner(i: *u32) void {
    var c = Counter{};
    // std.debug.print("spanwing other job\n", .{});
    i.* += 1;
    run(other, .{i}, &c) catch unreachable;
    // std.debug.print("waiting for other job\n", .{});
    wait(&c, 0);
    // std.debug.print("spawn done\n", .{});
}

fn other(i: *u32) void {
    i.* += 1;
    // std.debug.print("hello from other job\n", .{});
}

test "job spawns job" {
    try init(std.testing.allocator);
    defer deinit();

    var job_c = Counter{};
    var a: u32 = 0;
    try run(spawner, .{&a}, &job_c);

    while (job_c.val() != 0) {}

    try std.testing.expect(a == 2);
}

fn doStuff(v: *u32, t: u32) void {
    var i: u32 = 0;
    while (i < t) : (i += 1) {
        v.* += 1;
    }
}

test "add a bunch of jobs" {
    try init(std.testing.allocator);
    defer deinit();

    var x: u32 = 0;
    var y: u32 = 0;
    var z: u32 = 0;

    var job_c = Counter{};

    try run(doStuff, .{ &x, 100 }, &job_c);
    try run(doStuff, .{ &y, 120 }, &job_c);
    try run(doStuff, .{ &z, 10 }, &job_c);

    // spin lock until all jobs are done
    while (job_c.val() != 0) {}

    try std.testing.expect(job_c.val() == 0);
    try std.testing.expect(x == 100);
    try std.testing.expect(y == 120);
    try std.testing.expect(z == 10);
}

fn sleeps(x: *u32) void {
    sleep(std.time.ns_per_s);
    x.* = 5;
}

test "sleep" {
    try init(std.testing.allocator);
    defer deinit();

    var x: u32 = 0;

    var job_c = Counter{};
    try run(sleeps, .{&x}, &job_c);

    try std.testing.expect(x == 0);
    std.time.sleep(std.time.ns_per_s);
    try std.testing.expect(x == 5);
}

/// waits until a file has changed
pub fn statCheck(file: *std.fs.File) void {
    const old_mod = (file.stat() catch unreachable).mtime;
    while (true) {
        const new_mod = (file.stat() catch unreachable).mtime;
        if (new_mod > old_mod) {
            return;
        }
        sleep(std.time.ns_per_s);
    }
}
/// waits for a counter to read the file
fn readOut(file: std.fs.File, c: *Counter, allocator: std.mem.Allocator) void {
    // wait for c to equal zero
    wait(c, 0);

    // read contents of file and print them
    const reader = file.reader();
    var buf = reader.readAllAlloc(allocator, 1024) catch {
        std.debug.print("could not read\n", .{});
        return;
    };
    defer allocator.free(buf);
    std.debug.print("contents: {s}\n", .{buf});
}

const test_tmp_dir = "tmp_test";
test "wait for file change" {
    const allocator = std.testing.allocator;
    try init(allocator);
    defer deinit();

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
    var file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    var i: u8 = 0;
    while (i < 3) : (i += 1) {
        var done = Counter{};
        var file_c = Counter{};
        try file.seekTo(0);

        try run(statCheck, .{&file}, &file_c);
        try run(readOut, .{ file, &file_c, allocator }, &done);

        try std.testing.expect(file_c.val() == 1);
        try std.fs.cwd().writeFile(file_path, contents2);

        std.time.sleep(std.time.ns_per_s);

        try std.testing.expect(file_c.val() == 0);
        try std.testing.expect(done.val() == 0);
    }
}

pub fn statCheckOpen(path: []const u8, file: *std.fs.File) void {
    file.* = std.fs.cwd().openFile(path, .{}) catch unreachable;
    const old_mod = (file.stat() catch unreachable).mtime;
    while (true) {
        const new_mod = (file.stat() catch unreachable).mtime;
        if (new_mod > old_mod) {
            return;
        }
        file.close();
        sleep(std.time.ns_per_s);
        file.* = std.fs.cwd().openFile(path, .{}) catch unreachable;
    }
}

test "real time" {
    const allocator = std.testing.allocator;
    try init(allocator);
    defer deinit();

    var file: std.fs.File = undefined;
    defer file.close();

    var file_c = Counter{};
    var n: u8 = 0;
    while (true) {
        if (file_c.val() == 0) {
            std.debug.print("\nfile changed\n", .{});
            if (n == 3) {
                break;
            }
            n += 1;
            try run(statCheckOpen, .{ "test.txt", &file }, &file_c);
        }
    }
}
