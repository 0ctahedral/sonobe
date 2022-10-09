const math = @import("math");
const Vec2 = math.Vec2;
const Mat4 = math.Mat4;

/// A 2d rectangle
pub const Rect = packed struct {
    /// x postion
    x: f32 = 0,
    /// y postion
    y: f32 = 0,
    /// width
    w: f32 = 0,
    /// height
    h: f32 = 0,

    /// does this rectangle intersect the given point
    pub fn intersectPoint(self: Rect, pos: Vec2) bool {
        return (pos.x >= self.x and
            pos.y >= self.y and
            pos.x <= self.x + self.w and
            pos.y <= self.y + self.h);
    }

    /// shrinks the rectangle on sides by amount
    pub fn shrink(self: Rect, amt: f32) Rect {
        const amt_2 = amt * 0.5;
        return .{
            .x = self.x + amt_2,
            .y = self.y + amt_2,
            .w = self.w - amt,
            .h = self.h - amt,
        };
    }
};
