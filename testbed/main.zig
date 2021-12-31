const std = @import("std");
const octal = @import("octal");

pub fn main() !void {
    var m = octal.math.Mat4.identity();

    std.log.info("{}", .{m.m[0][0]});
    std.log.info("{}", .{m.m[1][1]});
    std.log.info("{}", .{m.m[2][2]});
    std.log.info("{}", .{m.m[3][3]});
}
