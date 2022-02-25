const std = @import("std");
const expect = std.testing.expect;
const Ringbuffer = @import("containers.zig").Ringbuffer;

/// A job that is submitted to be run by a worker thread
const Job = struct {
    taskfn: fn () callconv(.Async) void = undefined,
    fn task(self: @This(), data: []align(8) u8) void {
        _ = @asyncCall(data, undefined, self.taskfn, .{});
    }
};

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
const ShelvedJob = struct {
    /// counter who's condition we must wait on
    counter: *Counter,
    /// function to resume from
    frame: anyframe,
};

var job_queue = Ringbuffer(anyframe, 10).init();
var wait_queue = Ringbuffer(ShelvedJob, 10).init();

fn wait(counter: *Counter) void {
    suspend {
        wait_queue.push(.{
            .frame = @frame(),
            .counter = counter,
        }) catch unreachable;
        std.debug.print("frame rescheduled\n", .{});
    }
}

fn run(job: Job, data: []align(8) u8) void {
    // add to job queue
    suspend {
        job_queue.push(@frame()) catch unreachable;
    }
    _ = async job.task(data);
}

var a: u32 = 0;
var c: Counter = Counter{ .value = 1 };
fn onesuspend() void {
    a += 1;
    std.debug.print("added 1\n", .{});
    wait(&c);
    a += 1;
    std.debug.print("added 1 again\n", .{});
}

var done = false;

fn loop() void {
    while (!done) {
        var tmp_queue = Ringbuffer(ShelvedJob, 10).init();

        while (wait_queue.pop()) |shelved| {
            // pop and check if the condition is met
            // if it is then we can run it
            // otherwise add to back of queue
            // for now there are no conditions
            if (shelved.counter.is_zero()) {
                std.debug.print("resuming frame\n", .{});
                // the frame is ready so we should push it to the
                // front of the job_queue
                // TODO: push front
                job_queue.push(shelved.frame) catch unreachable;
            } else {
                tmp_queue.push(shelved) catch {
                    wait_queue.push(shelved) catch unreachable;
                    break;
                };
            }
        }
        // put them back
        // TODO: is this the best way?
        while (tmp_queue.pop()) |j| {
            wait_queue.push(j) catch unreachable;
        }

        // then see if there are any new jobs to run
        while (job_queue.pop()) |job| {
            std.debug.print("starting job\n", .{});
            resume job;
        }
    }
}

test "queue while loop in thread" {
    a = 0;
    var data: [4096]u8 align(8) = undefined;
    try expect(job_queue.len == 0);

    _ = async run(.{
        .taskfn = onesuspend,
    }, data[0..]);

    try expect(a == 0);

    try expect(job_queue.len == 1);

    var t = try std.Thread.spawn(.{}, loop, .{});

    std.time.sleep(1 * std.time.ns_per_s);

    c.dec();

    std.time.sleep(1 * std.time.ns_per_s);

    done = true;

    t.join();

    try expect(job_queue.len == 0);
    try expect(a == 2);

    job_queue.clear();
}
