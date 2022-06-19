const std = @import("std");
const Vec2 = @import("math.zig").Vec2;
const Events = @import("events.zig");

var mouse = Mouse{};

/// initialize input subsytem
pub fn init() !void {
    // regiter for mouse events
    try Events.register(.MouseButton, setButton);
}

pub fn deinit() void {
    // reset everything
    mouse = Mouse{};
}

/// set the stae of a button
pub fn setButton(ev: Events.Event) bool {
    const bev = ev.MouseButton;
    const idx = @enumToInt(bev.button);

    var btn = &mouse.buttons[idx];

    if (bev.action == .press) {
        btn.*.action = .press;
    } else if (bev.action == .release) {
        if (btn.action != .none) {
            // TOOD: get distance
        }
        btn.*.action = .release;
    }

    std.log.debug("mouse: {}", .{mouse});

    return true;
}

/// set the position of the cursor
pub fn setCursorPos(ev: Events.Event) bool {
    _ = ev;
    return true;
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
};
