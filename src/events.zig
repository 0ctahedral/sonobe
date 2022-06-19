//! Event subsystem
//! Any callback registered to recieve events is uniquely identified by the
//! specific event and the funciton and object pointers.
//! This means the same object can register for multiple events,
//! and that multiple objects of the same type can register for the same event
//! with the same function.
const std = @import("std");
const Window = @import("platform/window.zig");

var initialized = false;

pub const EventType = enum {
    Quit,
    WindowResize,
    WindowClose,
    //KeyPress,
    //KeyRelease,
    //MousePress,
    //MouseRelease,
    //MouseMoved,
};

pub const WindowResizeEvent = struct {
    handle: Window.Handle = .null_handle,
    x: i16 = 0,
    y: i16 = 0,
    w: u16,
    h: u16,
};

pub const Event = union(EventType) {
    Quit,
    WindowClose: Window.Handle,
    WindowResize: WindowResizeEvent,
    //KeyPress: input.keys,
    //KeyRelease: input.keys,
    //MousePress: input.mouse_btns,
    //MouseRelease: input.mouse_btns,
    //MouseMoved: struct {x: i16, y: i16},
};

/// number of events
const EVENTS_LEN = @typeInfo(EventType).Enum.fields.len;

/// max number of callbacks for a particular event type
const MAX_CALLBACKS = 32;

/// a wrapper for a function and object to send
const Callback = struct {
    //obj: *anyopaque,
    func: fn (Event) void,
};

/// Where we store our different callbacks for different event types
var callbacks: [EVENTS_LEN][MAX_CALLBACKS]?Callback = undefined;

/// initialize the event subsystem
pub fn init() void {
    initialized = true;
    for (callbacks) |*clist| {
        for (clist) |*cb| {
            cb.* = null;
        }
    }
}

/// shutdown the event subsystem
pub fn deinit() void {
    initialized = false;
}

// get index of first null in callbacks
fn firstNull(event: EventType) ?usize {
    for (callbacks[@enumToInt(event)]) |cb, i| {
        if (cb == null) {
            return i;
        }
    }
    return null;
}

/// Register a callback for a specific event
pub fn register(event: EventType, func: anytype) !void {
    //if (!initialized) {
    //    return error.NotInitialized;
    //}

    std.log.info("registering event: {}", .{event});

    if (firstNull(event)) |idx| {
        callbacks[@enumToInt(event)][idx] = Callback{
            .func = func,
        };
        return;
    }

    return error.EventCallbacksFull;
}

// TODO: figure this out
//pub fn unregister(event: EventType, obj: anytype, func: anytype) !void {
//    if (!initialized) {
//        return error.NotInitialized;
//    }
//    //
//    const optr = @ptrCast(opaqueT, obj);
//    const idx: i8 = blk: {
//        var i: i8 = 0;
//        for (Callbacks[@enumToInt(event)].items) |c| {
//            if (c.obj == optr) {
//                break :blk i;
//            }
//            i += 1;
//        }
//        break :blk -1;
//    };
//
//    if (idx == -1) {
//        return error.CallbackNotFound;
//    }
//
//    // remove it if we find it
//    _ = Callbacks[@enumToInt(event)].swapRemove(@intCast(usize,idx));
//}

pub fn send(event: Event) void {
    for (callbacks[@enumToInt(event)]) |cb| {
        if (cb) |c| {
            c.func(event);
        }
    }
}
