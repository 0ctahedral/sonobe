const math = @import("../core/core.zig").math;
const Vec2 = math.Vec2;

pub const MouseMove = struct {
    pos: Vec2,
    delta: Vec2,
};

pub const Event = union(enum){ 
    quit: void,
    mouse_move: MouseMove,
};
