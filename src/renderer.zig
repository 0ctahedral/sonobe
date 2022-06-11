//! Renderer front end

const std = @import("std");
const Allocator = std.mem.Allocator;
const Platform = @import("platform.zig");
const Events = @import("events.zig");

const Transform = @import("math.zig").Transform;

// TODO: make private and depend on which backend we are using
pub const backend_string = "vulkan";
const backend = @import("renderer/vulkan/renderer.zig");

pub const CmdBuf = @import("renderer/cmdbuf.zig");

// pub const Resource = @import("renderer/resource.zig");

pub fn init(provided_allocator: Allocator, app_name: [*:0]const u8, window: Platform.Window) !void {
    try backend.init(provided_allocator, app_name, window);

    // TODO: remove this when we have an api for changing stuff about the mesh
    var t: Transform = .{};
    t.pos = .{ .x = 0, .y = 0, .z = 0 };
    t.scale = .{ .x = 10, .y = 10, .z = 0 };
    backend.push_constant.model = t.mat();

    // register for resize event
    try Events.register(Events.EventType.WindowResize, onResize);
}

// TODO: make a command pool api
pub fn getCmdBuf() CmdBuf {
    return .{};
}

pub fn drawFrame(cmdbuf: CmdBuf) !void {
    _ = cmdbuf;
    if (try backend.beginFrame()) {
        try backend.endFrame();
    }
}

pub fn deinit() void {
    backend.deinit();
}

pub fn onResize(ev: Events.Event) void {
    // TODO: make this only happen when 30 frames have passed since last resize event
    const w = ev.WindowResize.w;
    const h = ev.WindowResize.h;
    backend.onResize(w, h);
}

pub const Handle = enum(u32) {
    null_handle = 0,
};

pub fn newBuffer(size: usize, kind: backend.BufferType) !Handle {
    backend.newBuffer(size, kind);
    return Handle{1};
}
