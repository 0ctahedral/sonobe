const std = @import("std");
const expect = std.testing.expect;

var saved_frame: anyframe = undefined;

/// Schedules to the target frame
fn scheduleFrame(target: *anyframe) void {
    suspend {
        target.* = @frame();
        std.debug.print("frame scheduled\n", .{});
    }
}

fn schedule() void {
    suspend {
        saved_frame = @frame();
        std.debug.print("frame scheduled\n", .{});
    }
}

const Job = struct {
    taskfn: fn ()  callconv(.Async) void = undefined,
    fn task(self: @This(), data: []align(8) u8) void {
        _ = @asyncCall(data, undefined, self.taskfn, .{});
    }
};

fn runJob(job: Job) void {
    scheduleFrame(&saved_frame);
    var data: [4096] u8 align(8) = undefined;
    _ = async job.task(data[0..]);
}

fn onesuspend() void {
    a += 1;
    std.debug.print("added 1\n", .{});
    scheduleFrame(&saved_frame);
    a += 1;
    std.debug.print("added 1 again\n", .{});
}

var a: u32 = 0;

test "one job" {
    _ = async runJob(.{
        .taskfn = onesuspend,
    });

    try expect(a == 0);

    resume saved_frame;

    try expect(a == 1);

    resume saved_frame;

    try expect(a == 2);
}

test "queue" {

}
