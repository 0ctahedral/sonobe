//! Transforms!
//! Stores an models's world space and stuff for use in the model matrix

const std = @import("std");
const testing = std.testing;
const math = std.math;
const Vec3 = @import("vec3.zig").Vec3;
const Quat = @import("quat.zig").Quat;
const Mat4 = @import("mat4.zig").Mat4;
const util = @import("util.zig");

/// A Transform of a model
pub const Transform = struct {
    /// the position in world space
    pos: Vec3 = .{},
    /// the rotation in world space
    rot: Quat = .{},
    /// the scale in world space
    scale: Vec3 = Vec3.new(1, 1, 1),

    // parent: ?*Transform = null,

    const Self = @This();

    /// get the local transformation matrix of the model
    pub fn local(self: Self) Mat4 {
        // start with the rotation
        return self.rot.toMat4()
            // apply posiition
            .mul(Mat4.translate(self.pos))
            // apply scale
            .mul(Mat4.scale(self.scale));
    }

    /// get the transform of this model based on ancestors
    pub fn world(self: Self) Mat4 {
        if (self.parent) |p| {
           return self.local().mul(p.world());
        } else {
            return self.local();
        }
    }
};

test "init" {
   var t = Transform{}; 

   try testing.expect(t.pos.eql(Vec3{}));
   try testing.expect(t.scale.eql(Vec3{.x = 1, .y = 1, .z = 1}));
   try testing.expect(t.rot.eql(Quat{}));
   try testing.expect(t.parent == null);
}

test "local" {
   var t = Transform{}; 
   var l = t.local();
   try testing.expect(l.eql(Mat4.identity()));
}

test "world" {
   var t = Transform{}; 
   var l = t.local();
   try testing.expect(l.eql(t.world()));

   var t2 = Transform{
       .pos = Vec3.new(1, 0, 0),
       .rot = Quat.fromAxisAngle(Vec3.new(0, 0, 1), math.pi / 2.0),
   };

   t.parent = &t2;


   var w = t.world().m;
   var we = Mat4.translate(Vec3.new(0, 1, 0)).m;
   std.debug.print("\n{}\n", .{t.world()});
   std.debug.print("\n{}\n", .{Mat4.translate(Vec3.new(0, 1, 0))});

   var row: usize = 0;
   while (row < 4) : (row += 1) {
       var col: usize = 0;
       while (col < 4) : (col += 1) {
           try testing.expectApproxEqAbs(w[row][col], we[row][col], 0.001);
           try testing.expectApproxEqAbs(w[row][col], we[row][col], 0.001);
           try testing.expectApproxEqAbs(w[row][col], we[row][col], 0.001);
       }
   }
}
