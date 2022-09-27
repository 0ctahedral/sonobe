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
};

pub const default = Logger("");

pub fn Logger(
    comptime prefix: []const u8,
) type {
    return struct {

        /// output file for the logger, defaults to stderr
        pub const out_file = std.io.getStdErr();

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
            const level_prefix = "[" ++ blk: {
                const lvl = @tagName(level);
                if (prefix.len == 0) {
                    break :blk lvl;
                } else {
                    break :blk prefix ++ ": " ++ lvl;
                }
            } ++ "] ";

            out_file.writer().print(color ++ level_prefix ++ fmt ++ color_clear ++ "\n", args) catch return;
        }
    };
}

test "log colors" {
    const log = Logger("");
    inline for (@typeInfo(Level).Enum.fields) |f| {
        log.logLevel(@field(Level, f.name), "{s}: bloopy", .{f.name});
    }
}

test "log prefix" {
    const log = Logger("prefix");
    inline for (@typeInfo(Level).Enum.fields) |f| {
        log.logLevel(@field(Level, f.name), "{s}: bloopy", .{f.name});
    }
}
