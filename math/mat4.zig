const std = @import("std");
const testing = std.testing;
const math = std.math;

/// a ROW MAJOR 4 by 4 matrix
pub const Mat4 = struct {
    // TODO: should this default to idenity?
    m: [4][4]f32 = std.mem.zeroes([4][4]f32),

    const Self = @This();

    /// returns an identity matrix
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

    /// multipliplies two matricies together
    pub fn mul(l: Self, r: Self) Self {
        // matrix to return
        var mat = Self.identity();
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

                mat.m[row][col] = sum;
            }
        }

        return mat;
    }

    /// inverse of a matrix
    pub fn inv(mat: Self) Self {
        // matrix to return
        var inv_mat = Self.identity();

        // determinant of a = |a|
        // cofactor of a is c
        // a^-1 = 1/|a| c^T

        var s: [6]f32 = undefined;
        var c: [6]f32 = undefined;

        s[0] = mat.m[0][0] * mat.m[1][1] - mat.m[1][0] * mat.m[0][1];
        s[1] = mat.m[0][0] * mat.m[1][2] - mat.m[1][0] * mat.m[0][2];
        s[2] = mat.m[0][0] * mat.m[1][3] - mat.m[1][0] * mat.m[0][3];
        s[3] = mat.m[0][1] * mat.m[1][2] - mat.m[1][1] * mat.m[0][2];
        s[4] = mat.m[0][1] * mat.m[1][3] - mat.m[1][1] * mat.m[0][3];
        s[5] = mat.m[0][2] * mat.m[1][3] - mat.m[1][2] * mat.m[0][3];

        c[0] = mat.m[2][0] * mat.m[3][1] - mat.m[3][0] * mat.m[2][1];
        c[1] = mat.m[2][0] * mat.m[3][2] - mat.m[3][0] * mat.m[2][2];
        c[2] = mat.m[2][0] * mat.m[3][3] - mat.m[3][0] * mat.m[2][3];
        c[3] = mat.m[2][1] * mat.m[3][2] - mat.m[3][1] * mat.m[2][2];
        c[4] = mat.m[2][1] * mat.m[3][3] - mat.m[3][1] * mat.m[2][3];
        c[5] = mat.m[2][2] * mat.m[3][3] - mat.m[3][2] * mat.m[2][3];

        const determ = 1.0 / (s[0] * c[5] - s[1] * c[4] + s[2] * c[3] + s[3] * c[2] - s[4] * c[1] + s[5] * c[0]);

        inv_mat.m[0][0] = (mat.m[1][1] * c[5] - mat.m[1][2] * c[4] + mat.m[1][3] * c[3]) * determ;
        inv_mat.m[0][1] = (-mat.m[0][1] * c[5] + mat.m[0][2] * c[4] - mat.m[0][3] * c[3]) * determ;
        inv_mat.m[0][2] = (mat.m[3][1] * s[5] - mat.m[3][2] * s[4] + mat.m[3][3] * s[3]) * determ;
        inv_mat.m[0][3] = (-mat.m[2][1] * s[5] + mat.m[2][2] * s[4] - mat.m[2][3] * s[3]) * determ;
        inv_mat.m[1][0] = (-mat.m[1][0] * c[5] + mat.m[1][2] * c[2] - mat.m[1][3] * c[1]) * determ;
        inv_mat.m[1][1] = (mat.m[0][0] * c[5] - mat.m[0][2] * c[2] + mat.m[0][3] * c[1]) * determ;
        inv_mat.m[1][2] = (-mat.m[3][0] * s[5] + mat.m[3][2] * s[2] - mat.m[3][3] * s[1]) * determ;
        inv_mat.m[1][3] = (mat.m[2][0] * s[5] - mat.m[2][2] * s[2] + mat.m[2][3] * s[1]) * determ;
        inv_mat.m[2][0] = (mat.m[1][0] * c[4] - mat.m[1][1] * c[2] + mat.m[1][3] * c[0]) * determ;
        inv_mat.m[2][1] = (-mat.m[0][0] * c[4] + mat.m[0][1] * c[2] - mat.m[0][3] * c[0]) * determ;
        inv_mat.m[2][2] = (mat.m[3][0] * s[4] - mat.m[3][1] * s[2] + mat.m[3][3] * s[0]) * determ;
        inv_mat.m[2][3] = (-mat.m[2][0] * s[4] + mat.m[2][1] * s[2] - mat.m[2][3] * s[0]) * determ;
        inv_mat.m[3][0] = (-mat.m[1][0] * c[3] + mat.m[1][1] * c[1] - mat.m[1][2] * c[0]) * determ;
        inv_mat.m[3][1] = (mat.m[0][0] * c[3] - mat.m[0][1] * c[1] + mat.m[0][2] * c[0]) * determ;
        inv_mat.m[3][2] = (-mat.m[3][0] * s[3] + mat.m[3][1] * s[1] - mat.m[3][2] * s[0]) * determ;
        inv_mat.m[3][3] = (mat.m[2][0] * s[3] - mat.m[2][1] * s[1] + mat.m[2][2] * s[0]) * determ;

        return inv_mat;
    }

    /// transposes a matrix
    pub fn trans(mat: Self) Self {
        // matrix to return
        var ret = mat;

        var col: usize = 0;
        while (col < 4) : (col += 1) {
            var row: usize = 0;
            while (row < 4) : (row += 1) {
                ret.m[row][col] = mat.m[col][row];
            }
        }

        return ret;
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

test "mul" {
    var i = Mat4.identity();
    var b = Mat4{ .m = .{
        .{ 1, 0, 0, 5 },
        .{ 0, 1, 0, 3 },
        .{ 0, 0, 1, 2 },
        .{ 0, 0, 0, 1 },
    } };
    var a = Mat4{ .m = .{
        .{ 1, 0, 0, 3 },
        .{ 0, 1, 0, 0 },
        .{ 0, 0, 1, 0 },
        .{ 0, 0, 0, 1 },
    } };
    // rotate 90 degrees
    var c = Mat4{ .m = .{
        .{ 1, 0, 0, 0 },
        .{ 0, -0.5, 0, 0 },
        .{ 0, 0, -0.5, 0 },
        .{ 0, 0, 0, 1 },
    } };

    // any multiplication with the identity is the same matrix
    try testing.expectEqual(i.mul(b), b);
    try testing.expectEqual(b.mul(i), b);

    // try with a different one
    try testing.expectEqual(a.mul(b).m, .{
        .{ 1, 0, 0, 8 },
        .{ 0, 1, 0, 3 },
        .{ 0, 0, 1, 2 },
        .{ 0, 0, 0, 1 },
    });

    // anotha one
    try testing.expectEqual(b.mul(c).m, .{
        .{ 1, 0, 0, 5 },
        .{ 0, -0.5, 0, 3 },
        .{ 0, 0, -0.5, 2 },
        .{ 0, 0, 0, 1 },
    });
}

test "inv" {
    var i = Mat4.identity();
    var a = Mat4{ .m = .{
        .{ 1, 0, 0, 5 },
        .{ 0, 1, 0, 3 },
        .{ 0, 0, 1, 2 },
        .{ 0, 0, 0, 1 },
    } };

    var b = Mat4{ .m = .{
        .{ 5, 0, 0, 10 },
        .{ 0, 0.5, 0, 6 },
        .{ 0, 0, 0.5, 4 },
        .{ 0, 0, 0, 5 },
    } };

    try testing.expectEqual(a.inv().m, .{
        .{ 1, 0, 0, -5 },
        .{ 0, 1, 0, -3 },
        .{ 0, 0, 1, -2 },
        .{ 0, 0, 0, 1 },
    });

    try testing.expectEqual(i.inv(), i);

    //.{
    //    .{ 0.2, 0, 0, -0.4 },
    //    .{ 0, 2, 0, -2.4 },
    //    .{ 0, 0, 2, -1.6 },
    //    .{ 0, 0, 0, 0.2 },
    //};
    try testing.expectApproxEqAbs(b.inv().m[0][0], 0.2, 0.001);
    try testing.expectApproxEqAbs(b.inv().m[0][1], 0, 0.001);
    try testing.expectApproxEqAbs(b.inv().m[0][2], 0, 0.001);
    try testing.expectApproxEqAbs(b.inv().m[0][3], -0.4, 0.001);

    try testing.expectApproxEqAbs(b.inv().m[1][0], 0, 0.001);
    try testing.expectApproxEqAbs(b.inv().m[1][1], 2, 0.001);
    try testing.expectApproxEqAbs(b.inv().m[1][2], 0, 0.001);
    try testing.expectApproxEqAbs(b.inv().m[1][3], -2.4, 0.001);

    try testing.expectApproxEqAbs(b.inv().m[2][0], 0, 0.001);
    try testing.expectApproxEqAbs(b.inv().m[2][1], 0, 0.001);
    try testing.expectApproxEqAbs(b.inv().m[2][2], 2, 0.001);
    try testing.expectApproxEqAbs(b.inv().m[2][3], -1.6, 0.001);

    try testing.expectApproxEqAbs(b.inv().m[3][0], 0, 0.001);
    try testing.expectApproxEqAbs(b.inv().m[3][1], 0, 0.001);
    try testing.expectApproxEqAbs(b.inv().m[3][2], 0, 0.001);
    try testing.expectApproxEqAbs(b.inv().m[3][3], 0.2, 0.001);
}

test "transpose" {
    var i = Mat4.identity();
    var a = Mat4{ .m = .{
        .{ 1, 0, 0, 5 },
        .{ 0, 1, 0, 3 },
        .{ 0, 0, 1, 2 },
        .{ 0, 0, 0, 1 },
    } };

    try testing.expectEqual(a.trans().m, .{
        .{ 1, 0, 0, 0 },
        .{ 0, 1, 0, 0 },
        .{ 0, 0, 1, 0 },
        .{ 5, 3, 2, 1 },
    });

    try testing.expectEqual(i.trans(), i);
}
