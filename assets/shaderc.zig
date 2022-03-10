//! a compiler for shaders
//! this allows us to have reflection data in the shader type itself

const std = @import("std");

pub const ShaderDec = struct {

    /// attributes that can be imported or exported from a shader
    pub const Attr = struct {
        name: []const u8,
    };

    inputs: []Attr,

    outputs: []Attr,

    code: []const u8,
};

test "triangle shader example" {
    const s = @embedFile("test.json");

    const allocator = std.testing.allocator;

    var stream = std.json.TokenStream.init(s);
    const data = try std.json.parse(ShaderDec, &stream, .{ .allocator = allocator });
    defer std.json.parseFree(ShaderDec, data, .{ .allocator = allocator });

    std.debug.print("code: {s}", .{data.code});
}
