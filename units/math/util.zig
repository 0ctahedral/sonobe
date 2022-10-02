//! some misc. utility functions
const std = @import("std");

// TODO: make use any type?
pub inline fn lerp(comptime T: type, from: T, to: T, t: T) T {
    return (1 - t) * from + t * to;
}

pub inline fn median(comptime T: type, a: T, b: T, c: T) T {
    return @maximum(@minimum(a, b), @minimum(@maximum(a, b), c));
}

pub inline fn clamp(
    comptime T: type,
    v: T,
    min: T,
    max: T,
) T {
    return @minimum(max, @maximum(min, v));
}

pub inline fn map(
    comptime T: type,
    v: T,
    fmin: T,
    fmax: T,
    tmin: T,
    tmax: T,
) T {
    return tmin + (v - fmin) * (tmax - tmin) / (fmax - fmin);
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

test "lerp" {
    try std.testing.expectApproxEqAbs(lerp(0, 100, 0.6), 60, 0.001);
}

test "map" {
    const eps = comptime std.math.epsilon(f32);
    try std.testing.expectApproxEqAbs(map(f32, 5, 0, 10, 20, 40), 30, eps);
    try std.testing.expectApproxEqAbs(map(f32, 30, 20, 40, 0, 10), 5, eps);
}

test "clamp" {
    const eps = comptime std.math.epsilon(f32);
    try std.testing.expectApproxEqAbs(clamp(f32, 7.0, -6.0, 20), 7, eps);
    try std.testing.expectApproxEqAbs(clamp(f32, -7.0, -6.0, 20), -6, eps);
    try std.testing.expectApproxEqAbs(clamp(f32, 0.8, 0.0, 0.6), 0.6, eps);
}

test "median" {
    const eps = comptime std.math.epsilon(f32);
    try std.testing.expect(median(u8, 1, 2, 3) == 2);
    try std.testing.expect(median(u8, 1, 3, 2) == 2);
    try std.testing.expect(median(u8, 2, 3, 1) == 2);
    try std.testing.expect(median(u8, 3, 2, 1) == 2);
    try std.testing.expectApproxEqAbs(median(f32, 3, 2, 1), 2, eps);
}
