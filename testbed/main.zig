const std = @import("std");
const octal = @import("octal");
const Renderer = octal.Renderer;
const mmath = octal.mmath;
const glfw = @import("glfw");

const app_name = "octal: triangle test";

fn cb(g: glfw.Window, w: i32, h: i32) void {
    _ = g;
    std.log.info("w: {}, h: {}", .{ w, h });
    Renderer.resize(@intCast(u32, w), @intCast(u32, h));
}

pub fn main() !void {
    // open the window
    // TODO: replace this with system function
    try glfw.init(.{});
    defer glfw.terminate();

    var width: u32 = 800;
    var height: u32 = 600;

    const window = try glfw.Window.create(width, height, app_name, null, null, .{
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
        const pos = try window.getCursorPos();
        if (try Renderer.beginFrame()) {
            try Renderer.updateUniform(mmath.Vec3.new(
                    @floatCast(f32, pos.xpos),
                    @floatCast(f32, pos.ypos),
            0));
            try Renderer.endFrame();
        }
    }
}
