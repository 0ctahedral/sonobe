//! these buffers are used for sumitting instructions for rendering a scene
const types = @import("rendertypes.zig");

const CmdBuf = @This();
/// Commands that are submitted with a command buffer
const Command = enum {
    /// begin a renderpass by id
    // BeginRenderPass,
    /// end a renderpass by id
    // EndRenderPass,
    /// draw geometry specified with some kind of indirection
    Draw,
    BeginRenderPass,
    EndRenderPass,
};

/// Desc that stores all the data related to the command
const CommandDecl = union(Command) {
    Draw: types.DrawDesc,
    BeginRenderPass: types.RenderPassDesc,
    EndRenderPass: types.RenderPassDesc,
};

/// maximum number of commands that can be held by a buffer
const MAX_COMMANDS = 32;

/// commands that have been submitted to this buffer
commands: [MAX_COMMANDS]CommandDecl = undefined,

/// last index that has been used by this buffer
idx: usize = 0,

// returns the current index and increases by one
inline fn getNextIdx(self: *CmdBuf) !usize {
    if (self.idx == self.commands.len - 1) {
        return error.MaxCommandsReached;
    }

    const ret = self.idx;
    self.idx += 1;
    return ret;
}

pub fn drawIndexed(self: *CmdBuf, descinfo: types.DrawDesc) !void {
    const idx = try self.getNextIdx();
    self.commands[idx] = .{ .Draw = descinfo };
}

pub fn beginRenderPass(self: *CmdBuf, desc: types.RenderPassDesc) !void {
    const idx = try self.getNextIdx();
    self.commands[idx] = .{ .BeginRenderPass = desc };
}

pub fn endRenderPass(self: *CmdBuf, desc: types.RenderPassDesc) !void {
    const idx = try self.getNextIdx();
    self.commands[idx] = .{ .EndRenderPass = desc };
}
