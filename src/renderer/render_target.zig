const std = @import("std");
const vk = @import("vulkan");
const Device = @import("device.zig").Device;
const Texture = @import("texture.zig").Texture;
const Pipeline = @import("pipeline.zig").Pipeline;

pub const RenderTarget = struct {
    // should this be updated with the window size?
    sync_window_size: bool = false,

    // render attachments
    // TODO: might change this to be more dynamic
    attachments: []Texture = &[_]Texture{},

    // frambuffer?
    framebuffer: vk.Framebuffer,

    const Self = @This();

    pub fn init(
        self: *Self,
        device: Device,
        renderpass: vk.RenderPass,
        attachments: []const Texture,
        width: u32,
        height: u32,
        allocator: std.mem.Allocator,
    ) !void {

        // allocate our textures if needed
        if (self.attachments.len != attachments.len) {
            self.attachments = try allocator.alloc(Texture, attachments.len);
        }

        var attachments_views: [32]vk.ImageView = undefined;
        for (attachments) |a, i| {
            self.attachments[i] = a;
            attachments_views[i] = a.image.view;
        }

        // create the framebuffer
        self.framebuffer = try device.vkd.createFramebuffer(device.logical, &.{
            .flags = .{},
            .render_pass = renderpass,
            .attachment_count = @intCast(u32, self.attachments.len),
            .p_attachments = @ptrCast([*]const vk.ImageView, &attachments_views),
            .width = width,
            .height = height,
            .layers = 1,
        }, null);
    }

    pub fn reset(
        self: *Self,
        device: Device,
    ) void {
        if (self.framebuffer != .null_handle) {
            device.vkd.destroyFramebuffer(device.logical, self.framebuffer, null);
        }
        self.framebuffer = .null_handle;
    }

    pub fn deinit(
        self: *Self,
        device: Device,
        allocator: std.mem.Allocator,
    ) void {
        self.reset(device);
        allocator.free(self.attachments);
    }
};
