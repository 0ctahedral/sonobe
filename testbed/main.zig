const std = @import("std");
const octal = @import("octal");
const cube = @import("cube.zig");

const Renderer = octal.Renderer;
const Resources = octal.Renderer.Resources;
const Input = octal.Input;
const CmdBuf = Renderer.CmdBuf;

const mmath = octal.mmath;
const Vec4 = mmath.Vec4;
const Vec3 = mmath.Vec3;
const Vec2 = mmath.Vec2;
const Quat = mmath.Quat;
const Mat4 = mmath.Mat4;
const Transform = mmath.Transform;

const Skybox = @import("skybox.zig");
const Camera = @import("camera.zig");

// since this file is implicitly a struct we can store state in here
// and use methods that we expect to be defined in the engine itself.
// we can then make our app a package which is included by the engine
const App = @This();

/// The name of this app (required)
pub const name = "testbed";

const positions = [_]Vec3{
    Vec3.new(-0.5, -0.5, 0),
    Vec3.new(0.5, 0.5, 0),
    Vec3.new(-0.5, 0.5, 0),
    Vec3.new(0.5, -0.5, 0),
};
const texcoords = [_]Vec2{
    Vec2.new(0.0, 0.0),
    Vec2.new(1.0, 1.0),
    Vec2.new(0.0, 1.0),
    Vec2.new(1.0, 0.0),
};
const quad_inds = [_]u32{ 0, 1, 2, 0, 3, 1 };

const MaterialData = struct {
    albedo: Vec4 = Vec4.new(1, 1, 1, 1),
    tile: Vec2 = Vec2.new(10, 10),
};

// internal state of the app
/// transform of the quad
t: Transform = .{},

quad_verts: Renderer.Handle = .{},
quad_inds: Renderer.Handle = .{},

world_pass: Renderer.Handle = .{},

camera: Camera = .{
    .pos = .{ .y = 2, .z = 5 },
},

material_group: Renderer.Handle = .{},
material_buffer: Renderer.Handle = .{},
material_data: MaterialData = .{},
default_texture: Renderer.Handle = .{},
default_sampler: Renderer.Handle = .{},

cube_verts: Renderer.Handle = .{},
cube_inds: Renderer.Handle = .{},

simple_pipeline: Renderer.Handle = .{},

last_pos: Vec2 = .{},

skybox: Skybox = .{},

camera_move_speed: f32 = 5.0,
pub fn init(app: *App) !void {

    // vertex and uv for cube
    {
        var cube_pos: [8]Vec3 = undefined;
        for (cube_pos) |*v, i| {
            v.* = Vec3.new(
                @intToFloat(f32, (i << 1) & 2) - 1,
                @intToFloat(f32, i & 2) - 1,
                @intToFloat(f32, (i >> 1) & 2) - 1,
            );
        }

        app.cube_verts = try Resources.createBuffer(
            .{
                .size = @sizeOf(@TypeOf(cube_pos)) + @sizeOf(@TypeOf(cube.uv)),
                .usage = .Vertex,
            },
        );
        var offset = try Renderer.updateBuffer(app.cube_verts, 0, Vec3, &cube_pos);
        offset = try Renderer.updateBuffer(app.cube_verts, offset, Vec2, &cube.uv);

        app.cube_inds = try Resources.createBuffer(
            .{
                .size = @sizeOf(@TypeOf(cube.indices)),
                .usage = .Index,
            },
        );
        _ = try Renderer.updateBuffer(app.cube_inds, 0, u32, &cube.indices);
    }
    app.t.pos = .{ .x = 0, .y = 1, .z = 0 };
    app.t.scale = .{ .x = 1, .y = 1, .z = 1 };

    // setup the quad

    app.quad_verts = try Resources.createBuffer(
        .{
            .size = @sizeOf(@TypeOf(texcoords)) + @sizeOf(@TypeOf(positions)),
            .usage = .Vertex,
        },
    );
    var offset = try Renderer.updateBuffer(app.quad_verts, 0, Vec3, positions[0..]);
    offset = try Renderer.updateBuffer(app.quad_verts, offset, Vec2, texcoords[0..]);

    app.quad_inds = try Resources.createBuffer(
        .{
            .size = @sizeOf(@TypeOf(quad_inds)),
            .usage = .Index,
        },
    );
    _ = try Renderer.updateBuffer(app.quad_inds, 0, u32, quad_inds[0..]);

    // setup the camera
    try app.camera.init();

    // setup the material
    app.material_group = try Resources.createBindingGroup(&.{
        .{ .binding_type = .Buffer },
        .{ .binding_type = .Texture },
        .{ .binding_type = .Sampler },
    });

    app.material_buffer = try Resources.createBuffer(
        .{
            .size = @sizeOf(MaterialData),
            .usage = .Uniform,
        },
    );
    _ = try Renderer.updateBuffer(app.material_buffer, 0, MaterialData, &[_]MaterialData{app.material_data});

    const tex_dimension: u32 = 2;
    const channels: u32 = 4;
    var pixels: [tex_dimension * tex_dimension * channels]u8 = .{
        0, 255, 0, 255, // 0, 0
        255, 255, 255, 255, // 0, 1
        255, 255, 255, 255, // 1, 0
        0, 255, 0, 255, // 1, 1
    };

    app.default_texture = try Resources.createTexture(.{
        .width = tex_dimension,
        .height = tex_dimension,
        .channels = channels,
        .flags = .{},
        .texture_type = .@"2d",
    }, &pixels);

    app.default_sampler = try Resources.createSampler(.{
        .filter = .nearest,
        .repeat = .wrap,
        .compare = .greater,
    });

    try Resources.updateBindings(app.material_group, &[_]Resources.BindingUpdate{
        .{ .binding = 0, .handle = app.material_buffer },
        .{ .binding = 1, .handle = app.default_texture },
        .{ .binding = 2, .handle = app.default_sampler },
    });

    app.world_pass = try Resources.createRenderPass(.{
        .clear_color = .{ 0.75, 0.49, 0.89, 1.0 },
        .clear_depth = 1.0,
        .clear_stencil = 1.0,
        .clear_flags = .{ .depth = true },
    });

    // create our shader pipeline
    app.simple_pipeline = try Resources.createPipeline(.{
        .stages = &.{
            .{
                .bindpoint = .Vertex,
                .path = "testbed/assets/default.vert.spv",
            },
            .{
                .bindpoint = .Fragment,
                .path = "testbed/assets/default.frag.spv",
            },
        },
        .binding_groups = &.{ app.camera.group, app.material_group },
        .renderpass = app.world_pass,
        .cull_mode = .back,
        .vertex_inputs = &.{ .Vec3, .Vec2 },
        .push_const_size = @sizeOf(Mat4),
    });

    app.skybox = try Skybox.init();
}

pub fn update(app: *App, dt: f64) !void {
    // camera stuff
    var input = Vec3{};
    if (Input.keyIs(.right, .down) or Input.keyIs(.d, .down)) {
        input = input.add(app.camera.rot.rotate(Vec3.RIGHT));
    }
    if (Input.keyIs(.left, .down) or Input.keyIs(.a, .down)) {
        input = input.add(app.camera.rot.rotate(Vec3.LEFT));
    }
    if (Input.keyIs(.up, .down) or Input.keyIs(.w, .down)) {
        input = input.add(app.camera.rot.rotate(Vec3.FORWARD));
    }
    if (Input.keyIs(.down, .down) or Input.keyIs(.s, .down)) {
        input = input.add(app.camera.rot.rotate(Vec3.BACKWARD));
    }
    if (Input.keyIs(.q, .down)) {
        input = input.add(Vec3.UP);
    }
    if (Input.keyIs(.e, .down)) {
        input = input.add(Vec3.DOWN);
    }

    if (Input.keyIs(.v, .press)) {
        app.camera.fov += 10;
        std.log.debug("fov changed to: {d:.2}", .{app.camera.fov});
    }
    if (Input.keyIs(.c, .press)) {
        app.camera.fov -= 10;
        std.log.debug("fov changed to: {d:.2}", .{app.camera.fov});
    }

    const mag = input.len();
    if (mag > 0.0) {
        app.camera.pos = app.camera.pos.add(input.scale(app.camera_move_speed * @floatCast(f32, dt) / mag));
    }

    const left = Input.getMouse().getButton(.left);
    if (left.action == .drag) {
        const ddrag = left.drag.sub(app.last_pos);
        app.camera.fpsRot(ddrag);
        app.last_pos = left.drag;
    } else {
        app.last_pos = .{};
    }
    try app.camera.update();

    // make that lil cube spin
    app.t.rot = app.t.rot
        .mul(Quat.fromAxisAngle(Vec3.FORWARD, mmath.util.rad(30) * @floatCast(f32, dt)))
        .mul(Quat.fromAxisAngle(Vec3.UP, mmath.util.rad(30) * @floatCast(f32, dt)));
    app.t.pos = Vec3.new(0, 1 + @sin(@intToFloat(f32, Renderer.frame) * 0.03), 0);

    try app.skybox.update(.{
        .proj = app.camera.proj(),
        .view = app.camera.view(),
        .albedo = Vec4.new(1, 1, 1, 0.5 + (@sin(@intToFloat(f32, Renderer.frame) * 0.03) / 2.0)),
    });
}

const floor_mat = Mat4.rotate(.x, -std.math.pi / 2.0)
    .mul(Mat4.scale(.{ .x = 100, .y = 100, .z = 100 }))
    .mul(Mat4.translate(.{ .y = -1 }));

pub fn render(app: *App) !void {
    var cmd = Renderer.getCmdBuf();

    // render skybox
    try app.skybox.draw(&cmd);
    // then render the geometry

    try cmd.beginRenderPass(app.world_pass);

    try cmd.bindPipeline(app.simple_pipeline);

    // draw the floor
    try cmd.pushConst(app.simple_pipeline, floor_mat);

    try cmd.drawIndexed(.{
        .count = quad_inds.len,
        .vertex_handle = app.quad_verts,
        .index_handle = app.quad_inds,
        .offsets = &.{ 0, 4 * @sizeOf(Vec3) },
    });

    // draw the magic cube
    try cmd.pushConst(app.simple_pipeline, app.t.mat());

    try cmd.drawIndexed(.{
        .count = cube.indices.len,
        .vertex_handle = app.cube_verts,
        .index_handle = app.cube_inds,
        .offsets = &.{ 0, 8 * @sizeOf(Vec3) },
    });

    try cmd.endRenderPass(app.world_pass);

    try Renderer.submit(cmd);
}

pub fn deinit(app: *App) void {
    _ = app;
    std.log.info("{s}: deinitialized", .{App.name});
}

pub fn onResize(app: *App, w: u16, h: u16) void {
    app.camera.aspect = @intToFloat(f32, w) / @intToFloat(f32, h);
}
