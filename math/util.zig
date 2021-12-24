//! some misc. utility functions

pub inline fn lerp(from: f32, to: f32, t: f32) f32 {
    return (1 - t) * from + t * to;
}
