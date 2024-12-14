const math = @import("../core.zig").math;
const Vec2 = math.Vec2;

pub const MouseMoveEvent = struct {
    wid: u32,
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
    wid: u32,
    button: MouseButton, 
    pos: Vec2,
    state: MouseButtonState,
};

pub const WindowCloseEvent = struct {
    wid: u32,
};

pub const Event = union(enum){ 
    quit: void,
    mouse_move: MouseMoveEvent,
    mouse_button: MouseButtonEvent,
    window_closed: WindowCloseEvent,
};
