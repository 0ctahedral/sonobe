const std = @import("std");
const fs = @import("fs");
const utils = @import("utils");
const FreeList = @import("containers").FreeList;
const resources = @import("device").resources;

const Handle = utils.Handle;
const PipelineDesc = resources.descs.PipelineDesc;

const MAX_MATERIALS = 32;

pub const Material = struct {
    /// handle of this materials pipeline
    pipeline: Handle(.Pipeline) = .{},
    /// description of this pipeline
    desc: PipelineDesc,
    /// handles to files we are watching for this
    watched: [PipelineDesc.MAX_STAGES]?Handle(.File) = [_]?Handle(.File){null} ** PipelineDesc.MAX_STAGES,

    paths: []const []const u8,
};

var allocator: std.mem.Allocator = undefined;
var watch: fs.Watch = undefined;

var materials: FreeList(Material) = undefined;

pub fn init(_allocator: std.mem.Allocator) !void {
    allocator = _allocator;

    watch = try fs.Watch.init(allocator);
    try watch.start();

    materials = try FreeList(Material).init(allocator, MAX_MATERIALS);
}

pub fn deinit() void {
    materials.deinit();
    watch.stop();
    watch.deinit();
}

pub fn update() !void {
    var iter = materials.iter();

    while (iter.next()) |mat| {
        var should_update = false;
        // check if any of our files have changed
        for (mat.watched) |handle| {
            if (handle) |h| {
                should_update = should_update or watch.modified(h);
            }
        }

        if (should_update) {
            try setupPipeline(mat, mat.paths);
        }
    }
}

pub fn createMaterial(
    desc: PipelineDesc,
    paths: []const []const u8,
) !Handle(.Material) {
    var mat = Material{
        .desc = desc,
        .paths = paths,
    };
    try setupPipeline(&mat, paths);

    const id = try materials.allocIndex();
    materials.set(id, mat);

    return Handle(.Material){ .id = id };
}

pub fn getPipeline(handle: Handle(.Material)) Handle(.Pipeline) {
    return materials.get(handle.id).pipeline;
}

fn setupPipeline(
    mat: *Material,
    paths: []const []const u8,
) !void {
    if (mat.pipeline.id != 0) {
        std.log.debug("deleting old pipeline", .{});
        resources.destroy(mat.pipeline.erased());
    } else {
        // only add file watches if the pipeline is new
        for (paths) |p, i| {
            mat.*.watched[i] = try watch.addFile(p);
        }
    }
    // const vert_path = "testbed/assets/default.vert.spv";
    // const frag_path = "testbed/assets/default.frag.spv";

    const vert_path = paths[0];
    const frag_path = paths[1];

    const vert_file = try std.fs.cwd().openFile(vert_path, .{ .read = true });
    defer vert_file.close();
    const frag_file = try std.fs.cwd().openFile(frag_path, .{ .read = true });
    defer frag_file.close();

    const vert_data = try allocator.alloc(u8, (try vert_file.stat()).size);
    _ = try vert_file.readAll(vert_data);
    defer allocator.free(vert_data);
    const frag_data = try allocator.alloc(u8, (try frag_file.stat()).size);
    _ = try frag_file.readAll(frag_data);
    defer allocator.free(frag_data);

    mat.*.desc.stages[0] = .{
        .bindpoint = .Vertex,
        .data = vert_data,
    };

    mat.*.desc.stages[1] = .{
        .bindpoint = .Fragment,
        .data = frag_data,
    };

    // create our shader pipeline
    mat.*.pipeline = try resources.createPipeline(mat.desc);
}
