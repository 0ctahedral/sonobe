const std = @import("std");
const fs = @import("fs");
const testing = std.testing;

test "interactive" {
    var w = try fs.Watch.init(testing.allocator);
    defer w.deinit();

    // add file
    const fh = try w.addFile("./test.txt");
    std.debug.print("file: {}\n", .{fh.id});

    // wait for the file to change
    try w.run();
}
