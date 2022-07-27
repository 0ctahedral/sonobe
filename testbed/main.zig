const std = @import("std");
const octal = @import("octal");

const Renderer = octal.Renderer;
const Resources = octal.Renderer.Resources;
const Input = octal.Input;
const CmdBuf = Renderer.CmdBuf;

const mmath = octal.mmath;
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

const CameraData = struct {
    projection: Mat4,
    view: Mat4,
    model: Mat4 = Mat4.identity(),
};

const MaterialData = struct {
    tile: Vec2 align(16) = Vec2.new(1, 1),
};

const Camera = struct {
    pos: Vec3,
    rot: Quat = Quat.fromAxisAngle(Vec3.UP, 0),
    projection: Mat4 = Mat4.perspective(mmath.util.rad(70), 800.0 / 600.0, 0.1, 1000),

    pub fn view(self: @This()) Mat4 {
        var ret = self.rot.toMat4();
        ret = ret.mul(Mat4.translate(self.pos));
        return ret.inv();
    }
};

// internal state of the app
/// angle that we have rotated the quad to
theta: f32 = 0,
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

simple_pipeline: Renderer.Handle = .{},

last_pos: Vec2 = .{},

pub fn init(app: *App) !void {
    _ = app;
    std.log.info("{s}: initialized", .{App.name});

    app.t.pos = .{ .x = 0, .y = 0, .z = 0 };
    app.t.scale = .{ .x = 1, .y = 1, .z = 0 };

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

    // renderpass
    const rp_desc = .{
        .clear_color = .{ 0.75, 0.49, 0.89, 1.0 },
        .clear_depth = 1.0,
        .clear_stencil = 1.0,
        .clear_flags = .{
            .color = true,
            .depth = true,
        },
    };

    app.world_pass = try Resources.createRenderPass(rp_desc);

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
    });
}

pub fn update(app: *App, dt: f64) !void {
    app.theta += (std.math.pi / 4.0) * @floatCast(f32, dt);
    // app.t.rot = Quat.fromAxisAngle(Vec3.FORWARD, app.theta);

    const mouse = Input.getMouse();
    const middle = mouse.getButton(.middle);

    var input = Vec3{};

    if (Input.getKey(.right) == .down) {
        input.x += 1.0;
    }
    if (Input.getKey(.left) == .down) {
        input.x -= 1.0;
    }
    if (Input.getKey(.up) == .down) {
        input.z += 1.0;
    }
    if (Input.getKey(.down) == .down) {
        input.z -= 1.0;
    }

    app.camera.pos = app.camera.pos.add(input.scale(@floatCast(f32, dt)));

    if (middle.action == .drag) {
        const amt = middle.drag.sub(app.last_pos);
        const dragScale = (-mmath.util.rad(60) / 400.0);
        const yaw = Quat.fromAxisAngle(Vec3.UP, amt.x * dragScale);
        const pitch = Quat.fromAxisAngle(Vec3.RIGHT, amt.y * dragScale);
        app.camera.rot = yaw.mul(pitch).mul(app.camera.rot).norm();
        // app.camera.rot = app.camera.rot.mul(yaw);
        app.last_pos = middle.drag;
    } else {
        app.last_pos = .{};
    }

    // update a constant value from struct rather than entire thing?
    // this would have to be something in a struct
    // where we could update by offset
    // try Resources.updateConst(app.camera_buffer, CameraData, .const_name, 35)
    _ = try Renderer.updateBuffer(app.camera_buffer, 0, CameraData, &[_]CameraData{.{
        .view = app.camera.view(),
        .projection = app.camera.projection,
        .model = app.t.mat(),
    }});
}

pub fn render(app: *App) !void {
    var cmd = Renderer.getCmdBuf();

    try cmd.beginRenderPass(app.world_pass);

    try cmd.bindPipeline(app.simple_pipeline);

    try cmd.drawIndexed(.{
        .count = 6,
        .vertex_handle = app.quad_verts,
        .index_handle = app.quad_inds,
    });

    try cmd.endRenderPass(app.world_pass);

    try Renderer.submit(cmd);
}

pub fn deinit(app: *App) void {
    _ = app;
    std.log.info("{s}: deinitialized", .{App.name});
}
