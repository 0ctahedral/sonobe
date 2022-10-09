const std = @import("std");
const utils = @import("utils");
const log = utils.log.default;
const Handle = utils.Handle;
const Color = utils.Color;
const mesh = @import("mesh");
const quad = mesh.quad;

const imgui = @import("imgui/imgui.zig");
const UI = imgui.UI;
const Rect = imgui.Rect;

const device = @import("device");
const descs = device.resources.descs;
const render = @import("render");
const resources = @import("device").resources;
const platform = @import("platform");
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

// color pallet namespace
const pallet = struct {
    pub const bg = Color.fromHex(0x190933);
    pub const bg_alt = Color.fromHex(0x40305D);

    pub const purple = Color.fromHex(0x665687);
    pub const active = Color.fromHex(0xB084CC);

    pub const fg = Color.fromHex(0xCDF3EE);
};

/// The name of this app (required)
pub const name = "testbed";

screen_pass: Handle(.RenderPass) = .{},

camera: Camera = .{
    .pos = .{ .y = -10, .z = 5 },
    .fov = 60,
},

ui: UI = .{},

button: UI.Id = .{},
slider: UI.Id = .{},
slider_value: f32 = 0,

dropdown: UI.Id = .{},

// dimesnsions of the device
dims: Vec2 = Vec2.new(800, 600),

const button_style = .{
    .color = pallet.bg_alt.toLinear(),
    .hover = pallet.purple.toLinear(),
    .active = pallet.active.toLinear(),
};

const slider_style = .{
    .slider_color = pallet.bg_alt.toLinear(),
    .color = pallet.purple.toLinear(),
    .hover = pallet.active.toLinear(),
    .active = pallet.fg.toLinear(),
};

const dropdown_style = .{
    .color = pallet.bg_alt.toLinear(),
    .hover = pallet.purple.toLinear(),
    .active = pallet.active.toLinear(),
    .text = pallet.fg.toLinear(),
};

pub fn init(app: *App) !void {
    // setup the camera
    try app.camera.init();
    app.camera.aspect = @intToFloat(f32, device.w) / @intToFloat(f32, device.h);

    // setup the material

    app.screen_pass = try resources.createRenderPass(.{
        .clear_color = pallet.bg.toLinear(),
        .clear_depth = 1.0,
        .clear_stencil = 1.0,
        .clear_flags = .{ .color = true, .depth = true },
    });

    app.ui = try UI.init(app.screen_pass, allocator);
}

pub fn update(app: *App, dt: f64) !void {
    // fps text
    {
        var buf: [80]u8 = undefined;
        const str = try std.fmt.bufPrint(
            buf[0..],
            "dt: {d:.2} fps: {d:.2}",
            .{
                dt * 1000.0,
                platform.fps(),
            },
        );
        app.ui.text(
            str,
            .{ .x = 0, .y = 0, .h = 25, .w = 230 },
            18,
            pallet.active.toLinear(),
        );
    }
    // buttons
    {
        const rect = UI.Rect{
            .x = app.dims.x - 110,
            .y = 10,
            .w = 100,
            .h = 50,
        };
        if (app.ui.button(&app.button, .{
            .rect = rect,
            .style = button_style,
        })) {
            log.debug("clicked", .{});
        }
        var text: []const u8 = "click me";
        app.ui.text(
            text,
            .{ .x = rect.x + 5, .y = rect.y + 5, .h = 20, .w = 75 },
            16,
            pallet.active.toLinear(),
        );
    }

    // lets try making a slider
    {
        const last_val = app.slider_value;
        const desc = UI.SliderDesc{
            .style = slider_style,
            .min = -100,
            .max = 100,
            .slider_rect = .{
                .x = app.dims.x - 175,
                .y = 75,
                .w = 100,
                .h = 10,
            },
            .handle_w = 10,
            .handle_h = 20,
            .ret_on_active = true,
        };
        var text_color = pallet.active.toLinear();
        if (app.ui.slider(
            &app.slider,
            &app.slider_value,
            desc,
        )) {
            text_color = pallet.fg.toLinear();
        }

        if (last_val != app.slider_value) {
            log.debug("new val: {d:.2}", .{app.slider_value});
        }

        // and lets print the value next to it
        var buf: [10]u8 = undefined;
        const str = try std.fmt.bufPrint(
            buf[0..],
            "{d:.2}",
            .{app.slider_value},
        );
        app.ui.text(
            str,
            .{
                .x = desc.slider_rect.x + desc.slider_rect.w + 10,
                .y = desc.slider_rect.y - 8,
                .h = 20,
                .w = 60,
            },
            16,
            text_color,
        );
    }

    // dropdown time
    {
        const texts = [_][]const u8{
            "one",
            "two",
            "three",
            "four",
            "five",
        };
        if (app.ui.dropdown(&app.dropdown, .{
            .rect = .{
                .x = app.dims.x - 100,
                .y = 100,
                .w = 80,
                .h = 20,
            },
            .text = "hello",
            .style = dropdown_style,
        })) {
            var i: u8 = 0;
            var rect = UI.Rect{
                .x = app.dims.x - 100,
                .y = 100,
                .w = 80,
                .h = 20,
            };
            while (i < 5) : (i += 1) {
                rect.y += 20;
                // dropdown item
                if (app.ui.dropdownItem(app.dropdown, .{
                    .rect = rect,
                    .text = texts[i],
                    .style = .{
                        .color = if (i % 2 == 0)
                            pallet.purple.toLinear()
                        else
                            pallet.bg_alt.toLinear(),
                        .hover = pallet.active.toLinear(),
                        .text = pallet.fg.toLinear(),
                    },
                })) {
                    log.debug("item[{}]: {s} selected", .{ i, texts[i] });
                }
            }
        }
    }
}

pub fn draw(app: *App) !void {
    var cmd = device.getCmdBuf();

    try cmd.beginRenderPass(app.screen_pass);

    try app.ui.draw(&cmd);

    try cmd.endRenderPass(app.screen_pass);

    try device.submit(cmd);
}

pub fn deinit(app: *App) void {
    app.ui.deinit();
    log.info("{s}: deinitialized", .{App.name});
}

pub fn onResize(app: *App, w: u16, h: u16) void {
    app.dims = Vec2.new(@intToFloat(f32, w), @intToFloat(f32, h));
    app.camera.aspect = app.dims.x / app.dims.y;
    app.ui.onResize() catch unreachable;
}
