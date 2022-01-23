const dispatch_types = @import("dispatch_types.zig");
const BaseDispatch = dispatch_types.BaseDispatch;
const InstanceDispatch = dispatch_types.InstanceDispatch;
const std = @import("std");
const vk = @import("vulkan");

pub const RenderPass = struct {
    handle: vk.RenderPass,


    /// extents of the render area
    /// aka start and end position
    //TODO: make this a vec4
    render_area: [4]f32,

    //TODO: make this a vec4
    clear_color: [4]f32,

    /// depth value
    depth: f32,

    const Self = @This();

    pub fn init(

    ) !Self {

        return error.NotImplemented;
    }

    pub fn deinit(self: Self) void {
        _ = self;
    }
};
