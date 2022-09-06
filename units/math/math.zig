//! math library!
pub const util = @import("util.zig");
pub const Vec2 = @import("vec2.zig").Vec2;
pub const Vec3 = @import("vec3.zig").Vec3;
pub const Vec4 = @import("vec4.zig").Vec4;
pub const Mat4 = @import("mat4.zig").Mat4;
pub const Quat = @import("quat.zig").Quat;
pub const Transform = @import("transform.zig").Transform;

test {
    @import("std").testing.refAllDecls(@This());
}
