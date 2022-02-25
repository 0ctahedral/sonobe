const backend = @import("renderer/backend.zig");

pub const init = backend.init;
pub const deinit = backend.deinit;
pub const updateUniform = backend.updateUniform;
pub const beginFrame = backend.beginFrame;
pub const endFrame = backend.endFrame;
