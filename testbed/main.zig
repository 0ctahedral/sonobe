const std = @import("std");
const octal = @import("octal");

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

// camera settings
const move_speed = 2.0;
const drag_scale = (-1 / 400.0);
const CameraData = struct {
    projection: Mat4,
    view: Mat4,
};

const MaterialData = struct {
    albedo: Vec4 = Vec4.new(1, 1, 1, 1),
    tile: Vec2 = Vec2.new(10, 10),
};

const Camera = struct {
    pos: Vec3,
    rot: Quat = Quat.fromAxisAngle(Vec3.UP, 0),
    projection: Mat4 = Mat4.perspective(mmath.util.rad(70), 800.0 / 600.0, 0.1, 1000),

    const Self = @This();

    /// compute the view matrix for the camera
    pub fn view(self: Self) Mat4 {
        var ret = self.rot.toMat4();
        return ret.mul(Mat4.translate(self.pos)).inv();
    }

    /// change the camera rotation based on a pitch and yaw vector
    pub fn updateRot(self: *Self, amt: Vec2) void {
        // const target = Vec3{};
        // const dir = self.pos.sub(target);
        // var rotated_dir = Quat.fromAxisAngle(Vec3.UP, amt.x).rotate(dir);
        // self.pos = self.pos.add(rotated_dir.sub(dir));
        // self.rot = self.rot.mul(Quat.lookAt(target, self.rot.rotate(Vec3.FORWARD), self.pos, Vec3.UP));
        // std.log.debug("{}", .{self.rot});

        const yaw = Quat.fromAxisAngle(Vec3.UP, amt.x);
        const pitch = Quat.fromAxisAngle(Vec3.RIGHT, amt.y);
        var new_rot = self.rot.mul(pitch);
        new_rot = yaw.mul(new_rot);
        self.rot = new_rot;
    }
};

// internal state of the app
/// transform of the quad
t: Transform = .{},

quad_verts: Renderer.Handle = .{},
quad_inds: Renderer.Handle = .{},

world_pass: Renderer.Handle = .{},

camera: Camera = .{
    .pos = .{ .z = 5 },
},
camera_group: Renderer.Handle = .{},
camera_buffer: Renderer.Handle = .{},

material_group: Renderer.Handle = .{},
material_buffer: Renderer.Handle = .{},
material_data: MaterialData = .{},
default_texture: Renderer.Handle = .{},
default_sampler: Renderer.Handle = .{},

skybox_pass: Renderer.Handle = .{},
skybox_pipeline: Renderer.Handle = .{},
cube_verts: Renderer.Handle = .{},
cube_inds: Renderer.Handle = .{},
skybox_buffer: Renderer.Handle = .{},
cubemap_texture: Renderer.Handle = .{},
cubemap_sampler: Renderer.Handle = .{},

simple_pipeline: Renderer.Handle = .{},

last_pos: Vec2 = .{},

pub fn init(app: *App) !void {

    // lets try to make a cube
    {
        var cube_pos: [8]Vec3 = undefined;
        // TODO get rid of when we configure pipeline input types
        const cube_uv = [_]Vec2{
            Vec2.new(0.0, 0.0),
            Vec2.new(1.0, 0.0),
            Vec2.new(0.0, 1.0),
            Vec2.new(1.0, 1.0),
            Vec2.new(0.0, 0.0),
            Vec2.new(1.0, 0.0),
            Vec2.new(0.0, 1.0),
            Vec2.new(1.0, 1.0),
        };
        for (cube_pos) |*v, i| {
            v.* = Vec3.new(
                @intToFloat(f32, (i << 1) & 2) - 1,
                @intToFloat(f32, i & 2) - 1,
                @intToFloat(f32, (i >> 1) & 2) - 1,
            );
        }

        app.cube_verts = try Resources.createBuffer(
            .{
                .size = @sizeOf(@TypeOf(cube_pos)) + @sizeOf(@TypeOf(cube_uv)),
                .usage = .Vertex,
            },
        );
        var offset = try Renderer.updateBuffer(app.cube_verts, 0, Vec3, cube_pos[0..]);
        offset = try Renderer.updateBuffer(app.cube_verts, offset, Vec2, cube_uv[0..]);

        app.cube_inds = try Resources.createBuffer(
            .{
                .size = @sizeOf(@TypeOf(cube_inds)),
                .usage = .Index,
            },
        );
        _ = try Renderer.updateBuffer(app.cube_inds, 0, u32, cube_inds[0..]);

        // std.log.debug("vec {d} x: {d:.2}, y: {d:.2}, z: {d:.2}", .{ i, vec.x, vec.y, vec.z });
    }

    std.log.info("{s}: initialized", .{App.name});

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

    app.camera_group = try Resources.createBindingGroup(&.{
        .{ .binding_type = .Buffer },
    });
    app.camera_buffer = try Resources.createBuffer(
        .{
            .size = @sizeOf(CameraData),
            .usage = .Uniform,
        },
    );
    try Resources.updateBindings(app.camera_group, &[_]Resources.BindingUpdate{
        .{ .binding = 0, .handle = app.camera_buffer },
    });

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
        .binding_groups = &.{ app.camera_group, app.material_group },
        .renderpass = app.world_pass,
        .cull_mode = .none,
        .vertex_inputs = &.{ .Vec3, .Vec2 },
        .push_const_size = @sizeOf(Mat4),
    });
    // skybox stuff
    // setup the texture
    app.skybox_pass = try Resources.createRenderPass(.{
        .clear_color = .{ 0.75, 0.49, 0.89, 1.0 },
        .clear_depth = 1.0,
        .clear_stencil = 1.0,
        .clear_flags = .{ .color = true, .depth = true },
    });

    var cube_pixels: [tex_dimension * tex_dimension * 6 * channels]u8 = .{
        // skybox order: +x, -x, +y, -y, +z, -z
        // red
        255, 0, 0, 255, // 0, 0
        255, 0, 0, 255, // 0, 1
        255, 0, 0, 255, // 1, 0
        255, 0, 0, 255, // 1, 1
        // cyan
        0, 255, 255, 255, // 0, 0
        0, 255, 255, 255, // 0, 1
        0, 255, 255, 255, // 1, 0
        0, 255, 255, 255, // 1, 1
        // green
        0, 255, 0, 255, // 0, 0
        0, 255, 0, 255, // 0, 1
        0, 255, 0, 255, // 1, 0
        0, 255, 0, 255, // 1, 1
        // magenta
        255, 0, 255, 255, // 0, 0
        255, 0, 255, 255, // 0, 1
        255, 0, 255, 255, // 1, 0
        255, 0, 255, 255, // 1, 1
        // blue
        0, 0, 255, 255, // 0, 0
        0, 0, 255, 255, // 0, 1
        0, 0, 255, 255, // 1, 0
        0, 0, 255, 255, // 1, 1
        // yellow
        255, 255, 0, 255, // 0, 0
        255, 255, 0, 255, // 0, 1
        255, 255, 0, 255, // 1, 0
        255, 255, 0, 255, // 1, 1
    };

    app.cubemap_texture = try Resources.createTexture(.{
        .width = tex_dimension,
        .height = tex_dimension,
        .channels = channels,
        .flags = .{},
        .texture_type = .cubemap,
    }, &cube_pixels);

    app.cubemap_sampler = try Resources.createSampler(.{
        // .filter = .bilinear,
        .filter = .nearest,
        .repeat = .wrap,
        .compare = .greater,
    });

    app.skybox_buffer = try Resources.createBuffer(
        .{
            .size = 2 * @sizeOf(Mat4),
            .usage = .Uniform,
        },
    );
    const skybox_group = try Resources.createBindingGroup(&.{
        .{ .binding_type = .Buffer },
        .{ .binding_type = .Texture },
        .{ .binding_type = .Sampler },
    });
    try Resources.updateBindings(skybox_group, &[_]Resources.BindingUpdate{
        .{ .binding = 0, .handle = app.skybox_buffer },
        .{ .binding = 1, .handle = app.cubemap_texture },
        .{ .binding = 2, .handle = app.cubemap_sampler },
    });

    // // create our shader pipeline
    app.skybox_pipeline = try Resources.createPipeline(.{
        .stages = &.{
            .{
                .bindpoint = .Vertex,
                .path = "testbed/assets/skybox.vert.spv",
            },
            .{
                .bindpoint = .Fragment,
                .path = "testbed/assets/skybox.frag.spv",
            },
        },
        .binding_groups = &.{skybox_group},
        .renderpass = app.skybox_pass,
        .cull_mode = .front,
    });
}

pub fn update(app: *App, dt: f64) !void {
    _ = dt;
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

    const mag = input.len();
    if (mag > 0.0) {
        app.camera.pos = app.camera.pos.add(input.scale(move_speed * @floatCast(f32, dt) / mag));
    }

    const left = Input.getMouse().getButton(.left);
    if (left.action == .drag) {
        const amt = left.drag.sub(app.last_pos).scale(drag_scale);
        app.camera.updateRot(amt);
        app.last_pos = left.drag;
    } else {
        app.last_pos = .{};
    }

    app.t.rot = app.t.rot
        .mul(Quat.fromAxisAngle(Vec3.FORWARD, mmath.util.rad(30) * @floatCast(f32, dt)))
        .mul(Quat.fromAxisAngle(Vec3.UP, mmath.util.rad(30) * @floatCast(f32, dt)));
    app.t.pos = Vec3.new(0, 1 + 1 * @sin(@intToFloat(f32, Renderer.frame) * 0.03), 0);

    // app.t.rot = Quat.lookAt(app.camera.pos, app.t.rot.rotate(Vec3.FORWARD), Vec3{}, app.t.rot.rotate(Vec3.UP));
    // update a constant value from struct rather than entire thing?
    // this would have to be something in a struct
    // where we could update by offset
    // try Resources.updateConst(app.camera_buffer, CameraData, .const_name, 35)
    _ = try Renderer.updateBuffer(app.camera_buffer, 0, CameraData, &[_]CameraData{.{
        .view = app.camera.view(),
        .projection = app.camera.projection,
    }});

    _ = try Renderer.updateBuffer(app.skybox_buffer, 0, Mat4, &[_]Mat4{
        app.camera.projection,
        app.camera.rot.toMat4(),
    });
}

const cube_inds = [_]u32{
    // back face
    1, 0, 3, //
    3, 0, 2, //

    // front face
    4, 5, 6, //
    5, 7, 6, //

    // left face
    2, 0, 4, //
    4, 6, 2, //

    // right face
    5, 1, 7, //
    7, 1, 3, //

    // top face
    2, 6, 7,
    7, 3, 2,

    // bottom face
    4, 0, 1,
    1, 5, 4,
};

const floor_mat = Mat4.rotate(.x, std.math.pi / 2.0)
    .mul(Mat4.scale(.{ .x = 100, .y = 100, .z = 100 }))
    .mul(Mat4.translate(.{ .y = -1 }));

pub fn render(app: *App) !void {
    var cmd = Renderer.getCmdBuf();

    // render skybox
    try cmd.beginRenderPass(app.skybox_pass);

    try cmd.bindPipeline(app.skybox_pipeline);

    try cmd.drawIndexed(.{
        .count = cube_inds.len,
        .vertex_handle = .{},
        .index_handle = app.cube_inds,
    });

    try cmd.endRenderPass(app.skybox_pass);

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
        .count = cube_inds.len,
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
