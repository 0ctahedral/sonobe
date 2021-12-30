//! some misc. utility functions
const std = @import("std");

pub inline fn lerp(from: f32, to: f32, t: f32) f32 {
    return (1 - t) * from + t * to;
}

/// Converts degrees to  radians 
pub fn rad(a: f32) f32 {
    return a * (std.math.pi / 180.0);
}

/// Converts radians to degrees
pub fn deg(a: f32) f32 {
    return a * (180.0 / std.math.pi);
}

test "deg to rad" {
    const eps = comptime std.math.epsilon(f32);
    try std.testing.expectApproxEqAbs(deg(std.math.pi), 180.0, eps);
    try std.testing.expectApproxEqAbs(rad(180.0), std.math.pi, eps);
}
