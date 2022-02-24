const std = @import("std");
const expect = std.testing.expect;

const Counter = struct {
    value: usize = 0,
};

const Shelved = struct {
    f: anyframe,
    c: ?Counter,
};

const Job = struct {
    task: fn () void,
    data: *u32,
};

//var shelf: [10]?Shelved = undefined;
var last: usize = 0;
var job_queue = [_]?Job{
    null,
} ** 10;

var counter = Counter{};

/// yeild this job until counter is 0
fn wait_for(c: *Counter) void {
    _ = c;
    suspend {
        // add current frame to queue
    }
}

/// adds a job to the queue
fn run_job(f: Job) void {
    job_queue[last] = f;
    last += 1;
}

fn main_loop() void {
    //while (true) {
    for (job_queue) |job, i| {
        if (job) |j| {
            std.debug.print("running job {d}\n", .{i});
            j.task.*(j.data);
            std.debug.print("ran job {d}\n", .{i});
            // remove job from queue
            job_queue[i] = null;
        }
    }
    //}
}

test "async" {
    var a: u32 = 0;

    //var ofn = &onesuspend;

    var data: [4096]u8 align(8) = undefined;

    //var f = @asyncCall(data[0..], undefined, onesuspend, .{&a});
    var j = Job{
        .task = onesuspend,
        .data = &a,
    };

    var f = @asyncCall(data[0..], undefined, j.task, .{j.data});

    try expect(a == 1);

    nosuspend await f;

    try expect(a == 2);

    //counter.value = 10;

    //std.debug.print("{}\n", .{@Frame(onesuspend)});

    //run_job(.{ .task = &onesuspend, .data = @ptrCast(*anyopaque, &a) });
    //var j = job_queue[0].?;
    //async j.task.*(j.data);

    //try expect(a == 1);

    //std.time.sleep(1 * std.time.ns_per_ms);
    //counter.value = 0;

    //var t = try std.Thread.spawn(.{}, main_loop, .{});
    //t.join();
}

fn onesuspend(i: *u32) void {
    i.* += 1;
    std.debug.print("added 1\n", .{});
    wait_for(&counter);
    i.* += 1;
    std.debug.print("added 1 again\n", .{});
}
