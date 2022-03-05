const backend = @import("renderer/backend.zig");

pub const mesh = @import("renderer/mesh.zig");

pub const init = backend.init;
pub const deinit = backend.deinit;
pub const updateUniform = backend.updateUniform;
pub const beginFrame = backend.beginFrame;
pub const endFrame = backend.endFrame;

// pipeline suff
pub const PipelineHandle = enum(u32) { null_handle = 0, _ };

/// Creates a user defined pipeline
pub fn createPipeline(
    /// stages of the pipeline
    /// specified (for now) as strings of the shader file paths
    stages: struct {
        vertex: ?[]const u8,
        fragment: ?[]const u8,
    },
) PipelineHandle {
    _ = stages;
    return .null_handle;
}

/// sets the pipeline used for the recording of the current frame
pub fn setPipeline(handle: PipelineHandle) void {
    _ = handle;
}
