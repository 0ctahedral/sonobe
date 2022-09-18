//! all the the available sonobe units, with dependencies sorted out 

pub const vulkan = .{
    .name = "vulkan",
    .path = .{ .path = "deps/vk.zig" },
};
pub const glfw = .{
    .name = "glfw",
    .path = .{ .path = "deps/mach-glfw/src/main.zig" },
};

pub const containers = @import("containers/build.zig").pkg;

pub const math = @import("math/build.zig").pkg;

pub const utils = @import("utils/build.zig").getPkg(&.{
    math,
});
pub const fs = @import("fs/build.zig").getPkg(&.{
    utils,
    containers,
});
pub const jobs = @import("jobs/build.zig").getPkg(&.{
    containers,
});
pub const platform = @import("platform/build.zig").getPkg(&.{
    utils,
    vulkan,
    glfw,
    math,
    containers,
});
pub const device = @import("device/build.zig").getPkg(&.{
    vulkan,
    math,
    containers,
    platform,
    utils,
});
pub const mesh = @import("mesh/build.zig").getPkg(&.{
    device,
    math,
    utils,
});
pub const font = @import("font/build.zig").getPkg(&.{
    device,
    math,
    utils,
    mesh,
});
pub const render = @import("render/build.zig").getPkg(&.{
    device,
    utils,
    mesh,
    math,
});
