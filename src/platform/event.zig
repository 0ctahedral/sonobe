const math = @import("../core/core.zig").math;
const Vec2 = math.Vec2;

pub const MouseMoveEvent = struct {
    pos: Vec2,
    delta: Vec2,
};

pub const MouseButton = enum(u3) {
    left = 1,
    middle = 2,
    right = 3,
    extra1 = 4,
    extra2 = 5,
    unkown,
};

pub const MouseButtonState = enum {
    pressed,
    released,
};

pub const MouseButtonEvent = struct {
    button: MouseButton, 
    pos: Vec2,
    state: MouseButtonState,
};

pub const Event = union(enum){ 
    quit: void,
    mouse_move: MouseMoveEvent,
    mouse_button: MouseButtonEvent,
};
