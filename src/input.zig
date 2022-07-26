const std = @import("std");
const Vec2 = @import("math.zig").Vec2;
const Events = @import("events.zig");

var mouse = Mouse{};

/// initialize input subsytem
pub fn init() !void {
    // regiter for mouse events
    try Events.register(.MouseButton, setMouseButton);
    try Events.register(.MouseMove, setMousePos);
    try Events.register(.KeyPress, setKeyState);
    try Events.register(.KeyRelease, setKeyState);
}

pub fn deinit() void {
    // reset everything
    mouse = Mouse{};
}

pub inline fn getMouse() Mouse {
    return mouse;
}

/// set the stae of a button
pub fn setMouseButton(ev: Events.Event) bool {
    const bev = ev.MouseButton;
    const idx = @enumToInt(bev.button);

    var btn = &mouse.buttons[idx];

    if (bev.action == .press) {
        btn.*.action = .press;
        btn.*.pressed = bev.pos;
        btn.*.drag = .{};
    } else if (bev.action == .release) {
        if (btn.action != .none) {
            const dir = bev.pos.sub(btn.pressed);
            btn.*.drag = dir;
        }
        btn.*.action = .release;
    }

    return true;
}

/// set the position of the cursor
pub fn setMousePos(ev: Events.Event) bool {
    // update the mouse position
    mouse.pos = ev.MouseMove;

    for (mouse.buttons) |*btn| {
        // don't need to do anything if the button is none or released
        if (btn.action == .none or btn.action == .release) continue;

        const drag = ev.MouseMove.sub(btn.pressed);
        const moved = !drag.eql(Vec2.new(0, 0));
        btn.*.drag = drag;

        // if the button is pressed and we moved then this is now a drag
        if (btn.action == .press and moved) {
            btn.*.action = .drag;
            // make vector of drag dist
        }
    }

    return true;
}

/// reset the mouse state if it was just released (typically at the end of a frame)
pub fn resetMouse() void {
    for (mouse.buttons) |*btn| {
        if (btn.action == .release) {
            btn.* = .{};
        }
    }
}

/// mouse input
pub const Mouse = struct {
    /// which mouse button is being used
    pub const Button = enum {
        left,
        right,
        middle,
        // TODO: add other ones (are there 8?)
    };
    const N_BUTTONS = @typeInfo(Button).Enum.fields.len;

    /// action a button can be in the process of
    pub const Action = enum {
        none,
        press,
        drag,
        release,
    };

    // TODO: add modifiers

    /// tracks state for a button
    pub const ButtonState = struct {
        /// the action the button is currently in
        action: Action = .none,

        /// location the button was first pressed
        pressed: Vec2 = .{},

        /// vector of the drag so far
        drag: Vec2 = .{},

        // TODO: double click and shit
    };

    buttons: [N_BUTTONS]ButtonState = [_]ButtonState{.{}} ** N_BUTTONS,

    pos: Vec2 = .{},

    pub inline fn getButton(self: Mouse, btn: Button) ButtonState {
        return self.buttons[@enumToInt(btn)];
    }
};

pub fn setKeyState(ev: Events.Event) bool {
    switch (ev) {
        .KeyPress => |k| {
            keymap[@enumToInt(k)] = .press;
        },
        .KeyRelease => |k| {
            keymap[@enumToInt(k)] = .release;
        },
        else => {},
    }
    return true;
}

pub fn resetKeyboard() void {
    for (keymap) |*s| {
        switch (s.*) {
            .press => s.* = .down,
            .release => s.* = .up,
            else => {},
        }
    }
}

pub fn getKey(key: Key) Key.State {
    return keymap[@enumToInt(key)];
}

pub const N_KEYS = @typeInfo(Key).Enum.fields.len;
var keymap: [N_KEYS]Key.State = [_]Key.State{.up} ** N_KEYS;
// TODO: do we need the numbers?
pub const Key = enum {
    pub const State = enum {
        press,
        down,
        release,
        up,
    };
    unknown,

    space,
    apostrophe,
    comma,
    minus,
    period,
    slash,
    semicolon,
    equal,
    a,
    b,
    c,
    d,
    e,
    f,
    g,
    h,
    i,
    j,
    k,
    l,
    m,
    n,
    o,
    p,
    q,
    r,
    s,
    t,
    u,
    v,
    w,
    x,
    y,
    z,
    left_bracket,
    backslash,
    right_bracket,
    grave,
    world_1, // non-US #1
    world_2, // non-US #2

    // Function keys
    escape,
    enter,
    tab,
    backspace,
    insert,
    delete,
    right,
    left,
    down,
    up,
    page_up,
    page_down,
    home,
    end,
    caps_lock,
    scroll_lock,
    num_lock,
    print,
    pause,
    f1,
    f2,
    f3,
    f4,
    f5,
    f6,
    f7,
    f8,
    f9,
    f10,
    f11,
    f12,
    f13,
    f14,
    f15,
    f16,
    f17,
    f18,
    f19,
    f20,
    f21,
    f22,
    f23,
    f24,
    f25,
    n0,
    n1,
    n2,
    n3,
    n4,
    n5,
    n6,
    n7,
    n8,
    n9,
    kp_0,
    kp_1,
    kp_2,
    kp_3,
    kp_4,
    kp_5,
    kp_6,
    kp_7,
    kp_8,
    kp_9,
    decimal,
    divide,
    multiply,
    subtract,
    add,
    l_shift,
    l_control,
    l_alt,
    l_super,
    r_shift,
    r_control,
    r_alt,
    r_super,
    menu,
};
