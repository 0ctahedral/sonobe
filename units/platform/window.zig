//! Window interface
const Handle = @import("utils").Handle;

const Window = @This();

handle: Handle(.Window) = .{},

pub const Size = struct {
    w: u32,
    h: u32,
};
