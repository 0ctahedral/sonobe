const std = @import("std");
const utils = @import("utils");
const Handle = utils.Handle;
const color = utils.color;
const mesh = @import("mesh");
const cube = mesh.cube;
const quad = mesh.quad;

const device = @import("device");
const render = @import("render");
const descs = device.resources.descs;
const resources = @import("device").resources;
const platform = @import("platform");
const input = platform.input;
const FontRen = @import("font").FontRen;
const CmdBuf = device.CmdBuf;

const material = @import("material.zig");

const math = @import("math");
const Vec4 = math.Vec4;
const Vec3 = math.Vec3;
const Vec2 = math.Vec2;
const Quat = math.Quat;
const Mat4 = math.Mat4;
const Transform = math.Transform;

const Skybox = render.Skybox;
const Camera = render.Camera;

const allocator = std.testing.allocator;
// since this file is implicitly a struct we can store state in here
// and use methods that we expect to be defined in the engine itself.
// we can then make our app a package which is included by the engine
const App = @This();

/// The name of this app (required)
pub const name = "testbed";

const MaterialData = struct {
    albedo: Vec4 = color.hexToVec4(0x70819BFF),
    tile: Vec2 = Vec2.new(10, 10),
};

// internal state of the app
/// transform of the quad
t: Transform = .{},

world_pass: Handle(.RenderPass) = .{},

screen_pass: Handle(.RenderPass) = .{},

camera: Camera = .{
    .pos = .{ .y = -10, .z = 5 },
    .fov = 60,
},

default_material: Handle(.Material) = .{},
material_group: Handle(.BindGroup) = .{},
material_buffer: Handle(.Buffer) = .{},
material_data: MaterialData = .{},

default_texture: Handle(.Texture) = .{},
default_sampler: Handle(.Sampler) = .{},

last_pos: Vec2 = .{},

skybox: Skybox = .{},

font_ren: FontRen = undefined,

octahedron: mesh.Mesh = undefined,
seamus: mesh.Mesh = undefined,

camera_move_speed: f32 = 5.0,

pub fn init(app: *App) !void {
    app.t.pos = .{ .x = 0, .y = 1, .z = 0 };
    app.t.scale = .{ .x = 1, .y = 1, .z = 1 };

    // setup the camera
    try app.camera.init();
    app.camera.aspect = @intToFloat(f32, device.w) / @intToFloat(f32, device.h);

    // setup the material
    app.material_group = try resources.createBindGroup(&.{
        .{ .binding_type = .UniformBuffer },
        .{ .binding_type = .Texture },
        .{ .binding_type = .Sampler },
    });

    app.material_buffer = try resources.createBuffer(
        .{
            .size = @sizeOf(MaterialData),
            .usage = .Uniform,
        },
    );
    _ = try resources.updateBufferTyped(app.material_buffer, 0, MaterialData, &[_]MaterialData{app.material_data});

    const tex_dimension: u32 = 2;
    const channels: u32 = 4;
    var pixels: [tex_dimension * tex_dimension * channels]u8 = .{
        0, 255, 0, 255, // 0, 0
        255, 255, 255, 255, // 0, 1
        255, 255, 255, 255, // 1, 0
        0, 255, 0, 255, // 1, 1
    };

    app.default_texture = try resources.createTexture(.{
        .width = tex_dimension,
        .height = tex_dimension,
        .channels = channels,
        .flags = .{},
        .texture_type = .@"2d",
    }, &pixels);

    app.default_sampler = try resources.createSampler(.{
        .filter = .nearest,
        .repeat = .wrap,
        .compare = .greater,
    });

    try resources.updateBindGroup(app.material_group, &[_]resources.BindGroupUpdate{
        .{ .binding = 0, .handle = app.material_buffer.erased() },
        .{ .binding = 1, .handle = app.default_texture.erased() },
        .{ .binding = 2, .handle = app.default_sampler.erased() },
    });

    app.world_pass = try resources.createRenderPass(.{
        .clear_color = Vec4.new(0.75, 0.49, 0.89, 1.0),
        .clear_depth = 1.0,
        .clear_stencil = 1.0,
        .clear_flags = .{ .depth = true },
    });

    app.screen_pass = try resources.createRenderPass(.{
        .clear_color = Vec4.new(0.75, 0.49, 0.89, 1.0),
        .clear_depth = 1.0,
        .clear_stencil = 1.0,
        .clear_flags = .{},
    });

    app.font_ren = try FontRen.init("./assets/fonts/scientifica-11.bdf", app.screen_pass, allocator);
    // update the buffer with our projection
    _ = try resources.updateBufferTyped(app.font_ren.buffer, 0, Mat4, &[_]Mat4{
        Mat4.ortho(0, 800, 0, 600, -100, 100),
    });
    app.skybox = try Skybox.init(app.camera, true, allocator);

    app.octahedron = try mesh.gltf.MeshFromGltf("assets/models/octahedron.glb", std.testing.allocator);
    app.seamus = try mesh.gltf.MeshFromGltf("assets/models/seamus.glb", std.testing.allocator);

    try material.init(allocator);

    var desc = descs.PipelineDesc{
        .renderpass = app.world_pass,
        .cull_mode = .back,
        .push_const_size = @sizeOf(PushConst),
    };
    desc.bind_groups[0] = app.camera.group;
    desc.bind_groups[1] = app.material_group;
    desc.vertex_inputs[0] = .Vec3;
    desc.vertex_inputs[1] = .Vec2;
    app.default_material = try material.createMaterial(desc, &[_][]const u8{
        "testbed/assets/default.vert.spv",
        "testbed/assets/default.frag.spv",
    });
}

pub fn update(app: *App, dt: f64) !void {

    // camera stuff
    var ivec = Vec3{};
    if (input.keyIs(.right, .down) or input.keyIs(.d, .down)) {
        ivec = ivec.add(app.camera.rot.rotate(Vec3.RIGHT));
    }
    if (input.keyIs(.left, .down) or input.keyIs(.a, .down)) {
        ivec = ivec.add(app.camera.rot.rotate(Vec3.LEFT));
    }
    if (input.keyIs(.up, .down) or input.keyIs(.w, .down)) {
        ivec = ivec.add(app.camera.rot.rotate(Vec3.FORWARD));
    }
    if (input.keyIs(.down, .down) or input.keyIs(.s, .down)) {
        ivec = ivec.add(app.camera.rot.rotate(Vec3.BACKWARD));
    }
    if (input.keyIs(.q, .down)) {
        ivec = ivec.add(Vec3.UP);
    }
    if (input.keyIs(.e, .down)) {
        ivec = ivec.add(Vec3.DOWN);
    }

    if (input.keyIs(.v, .press)) {
        app.camera.fov += 10;
        std.log.debug("fov changed to: {d:.2}", .{app.camera.fov});
    }
    if (input.keyIs(.c, .press)) {
        app.camera.fov -= 10;
        std.log.debug("fov changed to: {d:.2}", .{app.camera.fov});
    }

    const mag = ivec.len();
    if (mag > 0.0) {
        app.camera.pos = app.camera.pos.add(ivec.scale(app.camera_move_speed * @floatCast(f32, dt) / mag));
        //std.log.debug("x: {d:.2} y: {d:.2} z: {d:.2}", .{
        //    app.camera.pos.x,
        //    app.camera.pos.y,
        //    app.camera.pos.z
        //});
    }

    const left = input.getMouse().getButton(.left);
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
        .mul(Quat.fromAxisAngle(Vec3.FORWARD, math.util.rad(30) * @floatCast(f32, dt)))
        .mul(Quat.fromAxisAngle(Vec3.UP, math.util.rad(30) * @floatCast(f32, dt)));
    app.t.pos = Vec3.UP.scale(2 + @sin(@intToFloat(f32, device.frame) * 0.03));

    // render the framerate
    if (platform.frame_number % 10 == 0) {
        var buf: [80]u8 = undefined;
        app.font_ren.clear();
        _ = try app.font_ren.addString(
            try std.fmt.bufPrint(buf[0..], "dt: {d:.2} fps: {d:.2}", .{ platform.dt() * 1000.0, platform.fps() }),
            Vec2.new(0, 0),
            12,
            color.hexToVec4(0xffffffff),
        );
    }

    try material.update();
}

const floor_mat = Mat4.scale(.{ .x = 100, .y = 100, .z = 100 })
    .mul(Mat4.translate(.{ .y = -1 }));

const PushConst = struct {
    model: Mat4,
    mode: u32 = 0,
};

pub fn draw(app: *App) !void {
    var cmd = device.getCmdBuf();

    // render skybox
    try app.skybox.draw(&cmd);
    // then render the geometry

    try cmd.beginRenderPass(app.world_pass);

    const pl = material.getPipeline(app.default_material);
    try cmd.bindPipeline(pl);

    // render the floor
    try cmd.pushConst(pl, PushConst{ .model = floor_mat });

    const quad_bufs = try quad.getBuffers();
    try cmd.drawIndexed(
        @intCast(u32, quad.indices.len),
        quad_bufs.vertices,
        &.{ 0, 4 * @sizeOf(Vec3) },
        quad_bufs.indices,
        0,
    );

    // render the magic cube
    try cmd.pushConst(pl, PushConst{
        .model = app.t.mat(),
        .mode = 0,
    });

    const oct_bufs = try app.octahedron.getBuffers();
    const offsets = [_]u64{ 0, oct_bufs.uv_offset };
    try cmd.drawIndexed(
        @intCast(u32, app.octahedron.indices.items.len),
        oct_bufs.vertices,
        &offsets,
        oct_bufs.indices,
        0,
    );

    const seamus_bufs = try app.seamus.getBuffers();
    try cmd.drawIndexed(
        @intCast(u32, app.seamus.indices.items.len),
        seamus_bufs.vertices,
        &.{ 0, 8 * @sizeOf(Vec3) },
        seamus_bufs.indices,
        0,
    );

    try cmd.endRenderPass(app.world_pass);

    try cmd.beginRenderPass(app.screen_pass);
    try app.font_ren.drawGlyphs(&cmd);
    try cmd.endRenderPass(app.screen_pass);

    try device.submit(cmd);
}

pub fn deinit(app: *App) void {
    app.octahedron.deinit();

    material.deinit();
    std.log.info("{s}: deinitialized", .{App.name});
}

pub fn onResize(app: *App, w: u16, h: u16) void {
    app.camera.aspect = @intToFloat(f32, w) / @intToFloat(f32, h);
}
