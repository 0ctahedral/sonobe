//! Window interface
const vk = @import("vulkan");
const Platform = @import("../platform.zig");

const Window = @This();

pub const Handle = enum(u32) { null_handle = 0, _ };

/// Cross platform way of refering to this window
handle: Handle = .null_handle,
