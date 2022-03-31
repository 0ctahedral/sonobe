//! Window interface
const vk = @import("vulkan");
const Platform = @import("../platform.zig");


const Window = @This();


/// Handle of this window
pub const Handle = enum(u32) {
    null_handle = 0,
    _
};

/// Dimension of a window
pub const Extent = struct {
    w: u32,
    h: u32,
};

/// Cross platform way of refering to this window
handle: Handle = .null_handle,

getSizeFn: fn (Window) Extent,

pub inline fn getSize(win: Window) Extent {
    return win.getSizeFn(win);
}
