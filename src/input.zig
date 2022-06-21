const std = @import("std");
const Vec2 = @import("math.zig").Vec2;
const Events = @import("events.zig");

var mouse = Mouse{};

/// initialize input subsytem
pub fn init() !void {
    // regiter for mouse events
    try Events.register(.MouseButton, setMouseButton);
    try Events.register(.MouseMove, setMousePos);
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
    for (mouse.buttons) |*btn| {
        if (btn.action == .press) {
            // make vector of drag dist
            const dir = ev.MouseMove.sub(btn.pressed);
            btn.*.drag = dir;
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

    pub inline fn getButton(self: Mouse, btn: Button) ButtonState {
        return self.buttons[@enumToInt(btn)];
    }
};
