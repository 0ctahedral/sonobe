const std = @import("std");
const math = @import("sonobe.zig").math;
const Vec4 = math.Vec4;
const Vec3 = math.Vec3;

pub fn hexToVec4(hex: u32) Vec4 {
    const r: u8 = @truncate(u8, hex >> 24);
    const g: u8 = @truncate(u8, hex >> 16);
    const b: u8 = @truncate(u8, hex >> 8);
    const a: u8 = @truncate(u8, hex);

    return Vec4.new(
        @intToFloat(f32, r) / 255.0,
        @intToFloat(f32, g) / 255.0,
        @intToFloat(f32, b) / 255.0,
        @intToFloat(f32, a) / 255.0,
    );
}

pub fn hexToVec3(hex: u24) Vec3 {
    const r: u8 = @truncate(u8, hex >> 16);
    const g: u8 = @truncate(u8, hex >> 8);
    const b: u8 = @truncate(u8, hex);

    return Vec3.new(
        @intToFloat(f32, r) / 255.0,
        @intToFloat(f32, g) / 255.0,
        @intToFloat(f32, b) / 255.0,
    );
}

pub fn hexTou8(hex: u32) [4]u8 {
    var ret: [4]u8 = undefined;
    ret[0] = @truncate(u8, hex >> 24);
    ret[1] = @truncate(u8, hex >> 16);
    ret[2] = @truncate(u8, hex >> 8);
    ret[3] = @truncate(u8, hex);

    return ret;
}

test "u8" {
    const c = hexTou8(0x4287f5ff);

    try std.testing.expectEqual(c[0], 66);
    try std.testing.expectEqual(c[1], 135);
    try std.testing.expectEqual(c[2], 245);
    try std.testing.expectEqual(c[3], 255);
}

test "vec4" {
    const c = hexToVec4(0x4287f5ff);

    try std.testing.expectApproxEqAbs(@as(f32, 0.2588), c.x, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5294), c.y, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.9607), c.z, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0000), c.w, 0.01);
}
