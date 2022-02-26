const std = @import("std");
const expect = std.testing.expect;
const Ringbuffer = @import("containers.zig").Ringbuffer;

/// Basically a semaphore, indicates when a job dependency is done
const Counter = struct {
    /// value stored in this counter
    value: usize,

    const Self = @This();

    fn inc(self: *Self) void {
        _ = @atomicRmw(usize, &self.value, .Add, 1, .Monotonic);
    }

    fn dec(self: *Self) void {
        _ = @atomicRmw(usize, &self.value, .Sub, 1, .Monotonic);
    }

    fn is_zero(self: *Self) bool {
        return @atomicLoad(usize, &self.value, .Monotonic) == 0;
    }
};

/// A job that is waiting on a counter
const WaitingFrame = struct {
    /// counter who's condition we must wait on
    counter: *Counter,
    /// function to resume from
    frame: anyframe,
};

/// fibers that are ready
var frame_queue = Ringbuffer(anyframe, 10).init();
/// fibers that are waiting
var wait_queue = Ringbuffer(WaitingFrame, 10).init();

//fn wait(counter: *Counter, value?) void {
fn wait(counter: *Counter) void {
    suspend {
        wait_queue.push(.{
            .frame = @frame(),
            .counter = counter,
        }) catch unreachable;
        std.debug.print("frame rescheduled\n", .{});
    }
}

fn run(func: anytype, args: anytype, counter: *Counter) void {
    suspend {
        frame_queue.push(@frame()) catch unreachable;
    }

    // need to change the type to be async
    comptime var T = @typeInfo(@TypeOf(func));
    T.Fn.calling_convention = .Async;
    const f = @ptrCast(@Type(T), func);

    var stack: [4096]u8 align(8) = undefined;
    await @asyncCall(&stack, undefined, f, args);
    counter.dec();
}

fn onesuspend(a: *u32, c: *Counter) void {
    a.* += 1;
    std.debug.print("added 1\n", .{});
    wait(c);
    a.* += 1;
    std.debug.print("added 1 again\n", .{});
}

var done = false;

fn loop(tn: u32) void {
    while (!done) {
        var tmp_queue = Ringbuffer(WaitingFrame, 10).init();

        while (wait_queue.pop()) |shelved| {
            // pop and check if the condition is met
            // if it is then we can run it
            // otherwise add to back of queue
            // for now there are no conditions
            if (shelved.counter.is_zero()) {
                std.debug.print("resuming frame in {d}\n", .{tn});
                // TODO: push front
                frame_queue.push(shelved.frame) catch unreachable;
            } else {
                tmp_queue.push(shelved) catch {
                    wait_queue.push(shelved) catch unreachable;
                    break;
                };
            }
        }

        // put them back
        while (tmp_queue.pop()) |j| {
            wait_queue.push(j) catch unreachable;
        }

        // resume from a frame
        while (frame_queue.pop()) |frame| {
            resume frame;
        }
    }
}

test "queue while loop in thread" {
    var a: u32 = 0;
    var wait_c: Counter = Counter{ .value = 1 };

    var job_c = Counter{ .value = 1 };

    _ = async run(onesuspend, .{ &a, &wait_c }, &job_c);

    try expect(a == 0);
    try expect(job_c.value == 1);

    std.debug.print("job enqueued\n", .{});

    // TODO: lock to core
    var t = try std.Thread.spawn(.{}, loop, .{1});

    std.time.sleep(1 * std.time.ns_per_s);

    try expect(a == 1);
    try expect(job_c.value == 1);

    wait_c.dec();

    std.time.sleep(1 * std.time.ns_per_s);

    done = true;

    t.join();

    //try expect(job_queue.len == 0);
    try expect(a == 2);
    try expect(job_c.value == 0);
}
