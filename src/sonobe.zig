pub const color = @import("color.zig");
pub const font = @import("font.zig");
pub const jobs = @import("jobs.zig");
pub const mesh = @import("mesh.zig");
pub const device = @import("device.zig");
pub const render = @import("render.zig");

pub const containers = @import("containers");
pub const math = @import("math");
pub const platform = @import("platform");

const handle = @import("handle.zig");
pub const Handle = handle.Handle;
pub const ErasedHandle = handle.ErasedHandle;

test {
    @import("std").testing.refAllDecls(@This());
}
