//! Container library for use within subsystems
//! Will include hashmaps, arrays, and sets, and stuff
//!

// for tests
comptime {
    _ = @import("hash.zig");
}

pub const hash = @import("hash.zig");
