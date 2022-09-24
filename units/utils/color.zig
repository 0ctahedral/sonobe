const std = @import("std");
const math = @import("math");
const Vec4 = math.Vec4;
const Vec3 = math.Vec3;

pub const Color = packed struct {
    const Self = @This();

    r: f32 = 1.0,
    g: f32 = 1.0,
    b: f32 = 1.0,
    a: f32 = 1.0,

    pub fn rgb(r: f32, g: f32, b: f32) Self {
        return .{ .r = r, .g = g, .b = b };
    }

    pub fn rgba(r: f32, g: f32, b: f32, a: f32) Self {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn fromHex(hex: u32) Self {
        const r: u8 = @truncate(u8, hex >> 16);
        const g: u8 = @truncate(u8, hex >> 8);
        const b: u8 = @truncate(u8, hex);

        return .{
            .r = @intToFloat(f32, r) / 255.0,
            .g = @intToFloat(f32, g) / 255.0,
            .b = @intToFloat(f32, b) / 255.0,
        };
    }

    pub fn toNonLinear(self: Self) Self {
        var ret = Self{};
        inline for (@typeInfo(Self).Struct.fields) |f| {
            var v = @field(self, f.name);

            if (v <= 0) {
                //
            } else if (v <= 0.0031308) {
                v = v * 12.92;
            } else {
                v = (1.055 * std.math.pow(f32, v, 1 / 2.4)) - 0.055;
            }

            @field(ret, f.name) = v;
        }

        return ret;
    }

    pub fn toLinear(self: Self) Self {
        var ret = Self{};
        inline for (@typeInfo(Self).Struct.fields) |f| {
            var v = @field(self, f.name);

            if (v <= 0) {
                //
            } else if (v <= 0.04045) {
                v = v / 12.92;
            } else {
                v = std.math.pow(f32, (v + 0.055) / 1.055, 2.4);
            }

            @field(ret, f.name) = v;
        }

        return ret;
    }

    // TODO: hsl
};

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

test "fromHex" {
    const c = Color.fromHex(0x546896);
    const r: f32 = 84 / 255.0;
    const g: f32 = 104 / 255.0;
    const b: f32 = 150 / 255.0;
    try std.testing.expectApproxEqAbs(r, c.r, 0.001);
    try std.testing.expectApproxEqAbs(g, c.g, 0.001);
    try std.testing.expectApproxEqAbs(b, c.b, 0.001);
}

test "linear round trip" {
    const r = 6 / 255;
    const g = 57 / 255;
    const b = 112 / 255;
    const c = Color.rgb(r, g, b);
    const c2 = c.toNonLinear().toLinear();

    try std.testing.expectApproxEqAbs(c.r, c2.r, 0.001);
    try std.testing.expectApproxEqAbs(c.g, c2.g, 0.001);
    try std.testing.expectApproxEqAbs(c.b, c2.b, 0.001);
}
