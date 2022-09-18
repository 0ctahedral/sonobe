const std = @import("std");
const utils = @import("utils");
const Handle = utils.Handle;
const color = utils.color;
const mesh = @import("mesh");
const quad = mesh.quad;

const device = @import("device");
const descs = device.resources.descs;
const render = @import("render");
const resources = @import("device").resources;
const platform = @import("platform");
const input = platform.input;
const FontRen = @import("font").FontRen;
const CmdBuf = device.CmdBuf;

const math = @import("math");
const Vec4 = math.Vec4;
const Vec3 = math.Vec3;
const Vec2 = math.Vec2;
const Quat = math.Quat;
const Mat4 = math.Mat4;
const Transform = math.Transform;

const Camera = render.Camera;

const allocator = std.testing.allocator;
// since this file is implicitly a struct we can store state in here
// and use methods that we expect to be defined in the engine itself.
// we can then make our app a package which is included by the engine
const App = @This();

/// The name of this app (required)
pub const name = "testbed";

screen_pass: Handle(.RenderPass) = .{},

camera: Camera = .{
    .pos = .{ .y = -10, .z = 5 },
    .fov = 60,
},

ui_group: Handle(.BindGroup) = .{},
ui_pipeline: Handle(.Pipeline) = .{},
ui_data_buffer: Handle(.Buffer) = .{},
ui_idx_buffer: Handle(.Buffer) = .{},

last_pos: Vec2 = .{},

font_ren: FontRen = undefined,

const UIData = packed struct {
    rect: Vec4,
    color: Vec4,
};

const MAX_QUADS = 1024;
const BUF_SIZE = @sizeOf(Mat4) + MAX_QUADS * @sizeOf(UIData);

pub fn init(app: *App) !void {
    // setup the camera
    try app.camera.init();
    app.camera.aspect = @intToFloat(f32, device.w) / @intToFloat(f32, device.h);

    // setup the material
    app.ui_group = try resources.createBindGroup(&.{
        .{ .binding_type = .StorageBuffer },
    });

    app.ui_data_buffer = try resources.createBuffer(
        .{
            .size = BUF_SIZE,
            .usage = .Storage,
        },
    );
    _ = try resources.updateBufferTyped(app.ui_data_buffer, 0, Mat4, &[_]Mat4{
        Mat4.ortho(
            0,
            @intToFloat(f32, device.w),
            0,
            @intToFloat(f32, device.h),
            -100,
            100,
        ),
    });

    try resources.updateBindGroup(app.ui_group, &[_]resources.BindGroupUpdate{
        .{ .binding = 0, .handle = app.ui_data_buffer.erased() },
    });

    app.screen_pass = try resources.createRenderPass(.{
        .clear_color = Vec4.new(0.75, 0.49, 0.89, 1.0),
        .clear_depth = 1.0,
        .clear_stencil = 1.0,
        .clear_flags = .{ .color = true, .depth = true },
    });

    // create our shader pipeline

    const vert_file = try std.fs.cwd().openFile("testbed/assets/ui.vert.spv", .{ .read = true });
    defer vert_file.close();
    const frag_file = try std.fs.cwd().openFile("testbed/assets/ui.frag.spv", .{ .read = true });
    defer frag_file.close();

    const vert_data = try allocator.alloc(u8, (try vert_file.stat()).size);
    _ = try vert_file.readAll(vert_data);
    defer allocator.free(vert_data);
    const frag_data = try allocator.alloc(u8, (try frag_file.stat()).size);
    _ = try frag_file.readAll(frag_data);
    defer allocator.free(frag_data);

    var pl_desc = descs.PipelineDesc{
        .bind_groups = &.{app.ui_group},
        .renderpass = app.screen_pass,
        .cull_mode = .back,
        .vertex_inputs = &.{},
    };
    pl_desc.stages[0] = .{
        .bindpoint = .Vertex,
        .data = vert_data,
    };
    pl_desc.stages[1] = .{
        .bindpoint = .Fragment,
        .data = frag_data,
    };

    app.ui_pipeline = try resources.createPipeline(pl_desc);

    app.font_ren = try FontRen.init("./assets/fonts/scientifica-11.bdf", app.screen_pass, allocator);
    // update the buffer with our projection
    _ = try resources.updateBufferTyped(app.font_ren.buffer, 0, Mat4, &[_]Mat4{
        Mat4.ortho(0, 800, 0, 600, -100, 100),
    });
}

pub fn update(app: *App, dt: f64) !void {
    _ = app;
    _ = dt;
    app.font_ren.clear();
    var buf: [80]u8 = undefined;
    _ = try app.font_ren.addString(
        try std.fmt.bufPrint(buf[0..], "dt: {d:.2} fps: {d:.2}", .{ dt * 1000.0, platform.fps() }),
        Vec2.new(0, 0),
        12,
        color.hexToVec4(0xffffffff),
    );
}

pub fn draw(app: *App) !void {
    var cmd = device.getCmdBuf();

    try cmd.beginRenderPass(app.screen_pass);

    try app.font_ren.drawGlyphs(&cmd);

    try cmd.bindPipeline(app.ui_pipeline);

    try cmd.endRenderPass(app.screen_pass);

    try device.submit(cmd);
}

pub fn deinit(app: *App) void {
    _ = app;
    std.log.info("{s}: deinitialized", .{App.name});
}

pub fn onResize(app: *App, w: u16, h: u16) void {
    app.camera.aspect = @intToFloat(f32, w) / @intToFloat(f32, h);

    _ = resources.updateBufferTyped(app.font_ren.buffer, 0, Mat4, &[_]Mat4{
        Mat4.ortho(
            0,
            @intToFloat(f32, device.w),
            0,
            @intToFloat(f32, device.h),
            -100,
            100,
        ),
    }) catch unreachable;
}
