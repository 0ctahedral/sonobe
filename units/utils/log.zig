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

const COLOR_PREFIX = "\x1b[";
const COLOR_SUFFIX = "m";
const COLOR_CLEAR = "\x1b[0m";

pub fn Logger(
    comptime prefix: []const u8,
) type {
    return struct {
        /// output file for the logger, defaults to stderr
        pub var out_file = std.io.getStdErr();

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
            const color = COLOR_PREFIX ++ TERM_COLORS[@enumToInt(level)] ++ COLOR_SUFFIX;
            const level_prefix = "[" ++ blk: {
                const lvl = @tagName(level);
                if (prefix.len == 0) {
                    break :blk lvl;
                } else {
                    break :blk prefix ++ ": " ++ lvl;
                }
            } ++ "] ";

            out_file.writer().print(color ++ level_prefix ++ fmt ++ COLOR_CLEAR ++ "\n", args) catch return;
        }

        pub fn subLogger(
            comptime subPrefix: []const u8,
        ) type {
            return Logger(prefix ++ subPrefix);
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

test "sublogger" {
    const log = Logger("prefix");
    const sub = log.subLogger(".sub");

    log.info("logger", .{});
    sub.info("sub logger", .{});
}

test "change output file" {
    const log = Logger("prefix");
    log.out_file = std.io.getStdOut();

    const sub = log.subLogger(".sub");
    sub.out_file = std.io.getStdErr();

    log.info("stdout logger", .{});
    sub.info("stderr logger", .{});
}
