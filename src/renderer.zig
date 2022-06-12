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

    if (resizing) {
        frames_since_resize += 1;

        if (frames_since_resize >= 30) {
            backend.onResize(w, h);
            frames_since_resize = 0;
            resizing = false;
        } else {
            return;
        }
    }

    if (try backend.beginFrame()) {
        var i: usize = 0;
        while (i < cmdbuf.idx) : (i += 1) {
            switch (cmdbuf.commands[i]) {
                .Draw => |info| backend.drawGeometry(info),
                // anything else is a no-op for now
                else => {},
            }
        }
        try backend.endFrame();
    }
}

pub fn deinit() void {
    backend.deinit();
}

// State for resizing
var frames_since_resize: usize = 0;
var w: u16 = 800;
var h: u16 = 600;
var resizing = false;

pub fn onResize(ev: Events.Event) void {
    frames_since_resize = 0;
    w = ev.WindowResize.w;
    h = ev.WindowResize.h;
    resizing = true;
}

const types = @import("renderer/rendertypes.zig");
pub const Handle = types.Handle;
pub const BufferDesc = types.BufferDesc;
pub const RenderPassDesc = types.RenderPassDesc;

pub fn createBuffer(desc: BufferDesc) !Handle {
    return backend.Resources.createBuffer(desc);
}

/// uploades data to a buffer and returns the resulting offest in bytes
pub fn updateBuffer(
    handle: types.Handle,
    offset: usize,
    comptime T: type,
    data: []const T,
) !usize {
    const size = @sizeOf(T) * data.len;
    try backend.Resources.updateBuffer(
        handle,
        offset,
        @ptrCast([*]const u8, data),
        size,
    );
    return size + offset;
}
