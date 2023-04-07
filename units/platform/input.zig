const std = @import("std");
const Vec2 = @import("math").Vec2;
const events = @import("events.zig");

var mouse = Mouse{};

pub inline fn getMouse() Mouse {
    return mouse;
}

/// set the state of a button
pub fn setMouseButton(ev: events.Event) void {
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

    events.enqueue(ev);
}

/// set the position of the cursor
pub fn setMousePos(ev: events.Event) void {
    // update the mouse position
    const old_pos = mouse.pos;
    mouse.pos = ev.MouseMove;
    mouse.delta = mouse.pos.sub(old_pos);

    for (&mouse.buttons) |*btn| {
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
    events.enqueue(ev);
}

/// reset the mouse state if it was just released (typically at the end of a frame)
pub fn resetMouse() void {
    for (&mouse.buttons) |*btn| {
        if (btn.action == .release) {
            btn.* = .{};
        }
    }

    mouse.delta = .{};
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

    delta: Vec2 = .{},

    pub inline fn getButton(self: Mouse, btn: Button) ButtonState {
        return self.buttons[@enumToInt(btn)];
    }
};

pub fn setKeyState(ev: events.Event) void {
    switch (ev) {
        .KeyPress => |k| {
            keymap[@enumToInt(k)] = .press;
        },
        .KeyRelease => |k| {
            keymap[@enumToInt(k)] = .release;
        },
        else => {},
    }
    events.enqueue(ev);
}

pub fn setModifier(ev: events.Event) void {
    setKeyState(ev);

    switch (ev) {
        .KeyPress => |k| {
            switch (k) {
                .l_shift, .r_shift => modifiers.shift = true,
                .l_ctrl, .r_ctrl => modifiers.ctrl = true,
                .l_alt, .r_alt => modifiers.alt = true,
                .l_super, .r_super => modifiers.super = true,
                else => {},
            }
        },
        .KeyRelease => |k| {
            switch (k) {
                .l_shift => modifiers.shift = isKey(.r_shift, .down),
                .r_shift => modifiers.shift = isKey(.l_shift, .down),
                .l_ctrl => modifiers.ctrl = isKey(.r_ctrl, .down),
                .r_ctrl => modifiers.ctrl = isKey(.l_ctrl, .down),
                .l_alt => modifiers.alt = isKey(.r_alt, .down),
                .r_alt => modifiers.alt = isKey(.l_alt, .down),
                .l_super => modifiers.super = isKey(.r_super, .down),
                .r_super => modifiers.super = isKey(.l_super, .down),
                else => {},
            }
        },
        else => {},
    }
}

pub fn resetKeyboard() void {
    for (&keymap) |*s| {
        switch (s.*) {
            .press => s.* = .down,
            .release => s.* = .up,
            else => {},
        }
    }
}

/// get the state of a given key
pub inline fn getKey(key: Key) Key.State {
    return keymap[@enumToInt(key)];
}

/// return if the key is in a given state
pub inline fn isKey(key: Key, state: Key.State) bool {
    return keymap[@enumToInt(key)] == state;
}

/// return if modifiers are pressed
pub inline fn isMod(mod: ModState) bool {
    // check if mods are the same
    return modifiers.super == mod.super and
        modifiers.shift == mod.shift and
        modifiers.ctrl == mod.ctrl and
        modifiers.alt == mod.alt;
}

pub inline fn getMod() ModState {
    return modifiers;
}

pub const N_KEYS = @typeInfo(Key).Enum.fields.len;
var keymap: [N_KEYS]Key.State = [_]Key.State{.up} ** N_KEYS;
var modifiers = ModState{};

pub const ModState = packed struct {
    super: bool = false,
    shift: bool = false,
    ctrl: bool = false,
    alt: bool = false,
};

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
    exclam,
    pound,
    dollar,
    percent,
    ampersand,
    double_quote,
    l_paren,
    r_paren,
    asterisk,
    comma,
    plus,
    minus,
    period,
    slash,
    colon,
    semicolon,
    question,
    equal,
    less,
    greater,
    at,
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
    l_bracket,
    l_brace,
    backslash,
    bar,
    r_brace,
    r_bracket,
    underscore,
    grave,
    tilde,
    caret,
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
    l_ctrl,
    l_alt,
    l_super,
    r_shift,
    r_ctrl,
    r_alt,
    r_super,
    menu,
};
