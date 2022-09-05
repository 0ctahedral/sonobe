//! math library!
pub const util = @import("math/util.zig");
pub const Vec2 = @import("math/vec2.zig").Vec2;
pub const Vec3 = @import("math/vec3.zig").Vec3;
pub const Vec4 = @import("math/vec4.zig").Vec4;
pub const Mat4 = @import("math/mat4.zig").Mat4;
pub const Quat = @import("math/quat.zig").Quat;
pub const Transform = @import("math/transform.zig").Transform;

test {
    @import("std").testing.refAllDecls(@This());
}
