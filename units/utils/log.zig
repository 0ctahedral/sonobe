const std = @import("std");

const TERM_COLORS = [_][]const u8{
    "0;41",
    "1;31",
    "1;33",
    "1;32",
    "1;34",
    "1;30",
};

const Level = enum {
    Fatal,
    Error,
    Warn,
    Info,
    Debug,
    Trace,
};

const color_prefix = "\x1b[";
const color_suffix = "m";
const color_clear = "\x1b[0m";

var buffer: [4096]u8 = undefined;

pub fn logLevel(
    comptime level: Level,
    comptime fmt: []const u8,
    args: anytype,
) void {
    const color = color_prefix ++ TERM_COLORS[@enumToInt(level)] ++ color_suffix;

    const stderr = std.io.getStdErr().writer();
    stderr.print(color ++ fmt ++ color_clear ++ "\n", args) catch return;
}

test "log colors" {
    inline for (@typeInfo(Level).Enum.fields) |f| {
        logLevel(@field(Level, f.name), "{s}: bloopy", .{f.name});

        //printf("\033[%sm%s\033[0m", colour_strings[colour], message);
    }
}
