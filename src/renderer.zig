//! Renderer front end

// public declarations
pub const CmdBuf = @import("renderer/cmdbuf.zig");
pub const types = @import("renderer/rendertypes.zig");
pub const Handle = @import("octal.zig").Handle;
pub const BufferDesc = types.BufferDesc;
pub const RenderPassDesc = types.RenderPassDesc;
pub const PipelineDesc = types.PipelineDesc;
pub const resources = backend.resources;
pub const Camera = @import("renderer/camera.zig");
pub const Skybox = @import("renderer/skybox.zig");

// other stuff
const std = @import("std");
const Allocator = std.mem.Allocator;
const RingBuffer = @import("containers.zig").RingBuffer;
const Transform = @import("math.zig").Transform;
const backend = @import("renderer/vulkan/renderer.zig");
const platform = @import("platform.zig");
const events = @import("events.zig");

/// the current frame
pub var frame: usize = 0;
var submitted_cmds: RingBuffer(CmdBuf, 32) = undefined;
// State for resizing
var frames_since_resize: usize = 0;
// width and height of window, probs gonna get rid of this
pub var w: u32 = 800;
pub var h: u32 = 600;
var resizing = false;

pub fn init(_allocator: Allocator, app_name: [*:0]const u8, window: platform.Window) !void {
    try backend.init(_allocator, app_name, window);

    const size = try platform.getWindowSize(window);
    w = size.w;
    h = size.h;
    // register for resize event
    try events.register(events.EventType.WindowResize, onResize);

    submitted_cmds = RingBuffer(CmdBuf, 32).init();
}

// TODO: make a command pool api
pub fn getCmdBuf() CmdBuf {
    return .{};
}

/// Submit a command buffer to be run by the renderer
pub fn submit(cmdbuf: CmdBuf) !void {
    try submitted_cmds.push(cmdbuf);
}

pub fn drawFrame() !void {
    // regardless of control flow we need to reset the command buffer
    // at the end of this function
    defer submitted_cmds.clear();

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
        while (submitted_cmds.pop()) |cmdbuf| {
            try backend.submit(cmdbuf);
        }
        try backend.endFrame();
        frame += 1;
    }
}

pub fn deinit() void {
    backend.deinit();
}

pub fn onResize(ev: events.Event) bool {
    frames_since_resize = 0;
    w = @as(u32, ev.WindowResize.w);
    h = @as(u32, ev.WindowResize.h);
    resizing = true;

    // other systems might need this event
    return true;
}

/// uploades data to a buffer and returns the resulting offest in bytes
// TODO: make this just in the resources
pub fn updateBuffer(
    handle: Handle(null),
    offset: usize,
    comptime T: type,
    data: []const T,
) !usize {
    const size = @sizeOf(T) * data.len;
    try backend.resources.updateBuffer(
        handle,
        offset,
        @ptrCast([*]const u8, data),
        size,
    );
    return size + offset;
}
