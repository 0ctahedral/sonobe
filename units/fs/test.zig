const std = @import("std");
const fs = @import("fs");
const Handle = @import("utils").Handle;
const testing = std.testing;

fn changedloop(w: *fs.Watch, handles: []Handle(.File), paths: [][]const u8) void {
    var n: u8 = 0;
    while (true) {
        for (handles) |h, i| {
            if (w.modified(h)) {
                log.debug("n = {}, {s} modified!\n", .{ n, paths[i] });
                n += 1;
            }
        }

        if (n >= 3) {
            return;
        }

        std.time.sleep(std.time.ns_per_s);
    }
}

test "watch_get_modified" {
    var w = try fs.Watch.init(testing.allocator);
    defer w.deinit();

    // create and add files
    const contents =
        \\line 1
        \\line 2
    ;
    var paths = [_][]const u8{ "./test.txt", "./test1.txt" };
    var handles: [paths.len]Handle(.File) = undefined;

    for (paths) |path, i| {
        try std.fs.cwd().writeFile(path, contents);
        handles[i] = try w.addFile(path);
        log.debug("file[{}]: {s}\n", .{ handles[i].id, path });
    }

    try w.start();

    const new_contents =
        \\beepy
        \\baba
    ;

    for (paths) |path| {
        try std.fs.cwd().writeFile(path, new_contents);
    }

    var modified = [_]Handle(.File){ .{}, .{} };
    const n = w.getModified(&modified);
    try std.testing.expect(n == 2);

    log.debug("waiting for watcher to stop\n", .{});
    w.stop();
    log.debug("watcher to stoped\n", .{});

    for (paths) |path| {
        try std.fs.cwd().deleteFile(path);
    }
}

test "interactive_watch" {
    var w = try fs.Watch.init(testing.allocator);
    defer w.deinit();

    try w.start();

    // create and add files
    const contents =
        \\line 1
        \\line 2
    ;
    var paths = [_][]const u8{ "./test.txt", "./test1.txt", "./test2.txt" };
    var handles: [paths.len]Handle(.File) = undefined;

    for (paths) |path, i| {
        try std.fs.cwd().writeFile(path, contents);
        handles[i] = try w.addFile(path);
    }

    var cthread = try std.Thread.spawn(.{}, changedloop, .{ &w, &handles, &paths });

    const new_contents =
        \\beepy
        \\baba
    ;

    try std.fs.cwd().writeFile(paths[0], new_contents);

    cthread.join();
    log.debug("joined the change loop\n", .{});
    w.stop();

    // clean up the files
    for (paths) |path| {
        std.fs.cwd().deleteFile(path) catch {
            log.debug("cant find {s}\n", .{path});
        };
    }
}
