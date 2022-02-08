const std = @import("std");
const Renderer = @import("renderer.zig");
const vk = @import("vulkan");
const glfw = @import("glfw");
const mmath = @import("mmath");

const app_name = "octal: triangle test";

var width: i32 = 0;
var height: i32 = 0;

fn cb(g: glfw.Window, w: i32, h: i32) void {
    _ = g;
    std.log.info("w: {}, h: {}", .{w, h});
    width = w;
    height = h;
    Renderer.resize(@intCast(u32, w), @intCast(u32, h));
}

pub fn main() !void {
    // open the window
    // TODO: replace this with system function
    try glfw.init(.{});
    defer glfw.terminate();

    var extent = vk.Extent2D{ .width = 800, .height = 600 };

    const window = try glfw.Window.create(extent.width, extent.height, app_name, null, null, .{
        .client_api = .no_api,
        .floating = true,
    });
    defer window.destroy();

    //const allocator = std.heap.page_allocator;
    const allocator = std.testing.allocator;

    // setup renderer
    try Renderer.init(allocator, app_name, window);
    defer Renderer.deinit();

    window.setSizeCallback(cb);


    while (!window.shouldClose()) {
        try glfw.pollEvents();
        if (try Renderer.beginFrame()) {
            //const pos = try window.getCursorPos();
            // const newx: f32 = 1 - @intToFloat(f32, width)/@floatCast(f32, pos.xpos);
            // const newy: f32 = 1 - @intToFloat(f32, height)/@floatCast(f32, pos.ypos);
            // std.log.debug("x: {d:.2}, y: {d:.2} ", .{pos.xpos, pos.ypos});
            //Renderer.updateUniform(
            //    .{
            //        .view = mmath.Mat4.translate(
            //            mmath.Vec3.new(newx, newy, 0)
            //        ),
            //    }
            //);
            try Renderer.endFrame();
        }
    }
}
