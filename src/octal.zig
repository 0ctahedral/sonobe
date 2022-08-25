pub const color = @import("color.zig");
pub const events = @import("events.zig");
pub const font = @import("font.zig");
pub const input = @import("input.zig");
pub const jobs = @import("jobs.zig");
pub const math = @import("math.zig");
pub const mesh = @import("mesh.zig");
pub const gltf = @import("mesh/gltf.zig");
pub const platform = @import("platform.zig");
pub const renderer = @import("renderer.zig");
const handle = @import("handle.zig");
pub const Handle = handle.Handle;
pub const ErasedHandle = handle.ErasedHandle;

test {
    @import("std").testing.refAllDecls(@This());
}
