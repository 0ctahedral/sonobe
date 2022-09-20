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
    fatal,
    err,
    warn,
    info,
    debug,

    pub fn toSring(comptime self: @This()) switch (self) {
        .fatal => @TypeOf("fatal"),
        .err => @TypeOf("error"),
        .warn => @TypeOf("warn"),
        .info => @TypeOf("info"),
        .debug => @TypeOf("debug"),
    } {
        return switch (self) {
            .fatal => "fatal",
            .err => "error",
            .warn => "warn",
            .info => "info",
            .debug => "debug",
        };
    }
};

const color_prefix = "\x1b[";
const color_suffix = "m";
const color_clear = "\x1b[0m";

pub inline fn info(
    comptime fmt: []const u8,
    args: anytype,
) void {
    logLevel(.info, fmt, args);
}

pub inline fn err(
    comptime fmt: []const u8,
    args: anytype,
) void {
    logLevel(.err, fmt, args);
}

pub inline fn debug(
    comptime fmt: []const u8,
    args: anytype,
) void {
    logLevel(.debug, fmt, args);
}

pub inline fn warn(
    comptime fmt: []const u8,
    args: anytype,
) void {
    logLevel(.warn, fmt, args);
}

pub fn logLevel(
    comptime level: Level,
    comptime fmt: []const u8,
    args: anytype,
) void {
    const color = color_prefix ++ TERM_COLORS[@enumToInt(level)] ++ color_suffix;
    const stderr = std.io.getStdErr().writer();
    const prefix = "[" ++ comptime level.toSring() ++ "] ";
    stderr.print(color ++ prefix ++ fmt ++ color_clear ++ "\n", args) catch return;
}

test "log colors" {
    inline for (@typeInfo(Level).Enum.fields) |f| {
        logLevel(@field(Level, f.name), "{s}: bloopy", .{f.name});

        //printf("\033[%sm%s\033[0m", colour_strings[colour], message);
    }
}
