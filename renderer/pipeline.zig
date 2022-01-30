const std = @import("std");
const vk = @import("vulkan");
const Device = @import("device.zig").Device;

pub const Pipeline = struct {
    const Self = @This();
    
    handle: vk.Pipeline,
    layout: vk.PipelineLayout,

};
