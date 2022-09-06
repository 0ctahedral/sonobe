//! Window interface
const vk = @import("vulkan");

const Window = @This();

pub const Handle = enum(u32) { null_handle = 0, _ };

/// Cross platform way of refering to this window
handle: Handle = .null_handle,

pub const Size = struct {
    w: u32,
    h: u32,
};
