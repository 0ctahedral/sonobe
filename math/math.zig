//! math library!

comptime {
    _ = @import("util.zig");
    _ = @import("vec2.zig");
    _ = @import("vec3.zig");
    _ = @import("mat4.zig");
    _ = @import("quat.zig");
}

pub const util = @import("util.zig");
pub const Vec2 = @import("vec2.zig").Vec2;
pub const Vec3 = @import("vec3.zig").Vec3;
pub const Mat4 = @import("mat4.zig").Mat4;
pub const Quat = @import("quat.zig").Quat;
