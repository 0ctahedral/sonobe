const std = @import("std");
const testing = std.testing;
const math = std.math;

/// a ROW MAJOR 4 by 4 matrix
pub const Mat4 = struct {
    // TODO: should this default to idenity?
    m: [4][4]f32 = std.mem.zeroes([4][4]f32),

    const Self = @This();

    pub fn identity() Self {
        return .{
            .m = .{
                // ix, iy, iz, iw
                .{ 1, 0, 0, 0 },
                // jx, iy, iz, iw
                .{ 0, 1, 0, 0 },
                // kx, ky, kz, kw
                .{ 0, 0, 1, 0 },
                // tx, ty, tz, tw
                .{ 0, 0, 0, 1 },
            },
        };
    }

    pub fn mul(l: Self, r: Self) Self {
        // matrix to return
        var mat = Self.idenity();
        // for keeping track of the current op
        var row: usize = 0;

        while (row < 4) : (row += 1) {
            var col: usize = 0;
            while (col < 4) : (col += 1) {
                var sum: f32 = 0;
                var cur: usize = 0;

                while (cur < 4) : (cur += 1) {
                    sum += l.m[row][cur] * r.m[cur][col];
                }

                mat[row][col] = sum;
            }
        }

        return mat;
    }
};

test "init" {
    var m = Mat4.identity();
    try testing.expectEqual(m.m, .{
        .{ 1, 0, 0, 0 },
        .{ 0, 1, 0, 0 },
        .{ 0, 0, 1, 0 },
        .{ 0, 0, 0, 1 },
    });
}

test "init" {
    var i = Mat4.identity();
    var b = Mat4{ .m = .{
        .{ 1, 2, 3, 0 },
        .{ 0, 1, 0, 0 },
        .{ 0, 0, 1, 0 },
        .{ 0, 0, 0, 1 },
    } };

    try testing.expectEqual(i.mul(b), b);
    try testing.expectEqual(b.mul(i), b);
}
