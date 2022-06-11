//! these buffers are used for sumitting instructions for rendering a scene

const CmdBuf = @This();
/// Commands that are submitted with a command buffer
const Command = enum {
    /// begin a renderpass by id
    // BeginRenderPass,
    /// end a renderpass by id
    // EndRenderPass,
    /// draw geometry specified with some kind of indirection
    Draw,
};

/// Info that stores all the data related to the command
const CommandDecl = union(Command) {
    Draw: DrawInfo,
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

/// data for a draw call
/// right now it can only be indexed
pub const DrawInfo = struct {
    /// number of indices to draw
    count: u32,
    /// handle for the buffer we are drawing from
    handle: usize,
};

pub fn draw(self: *CmdBuf, info: DrawInfo) !void {
    const idx = self.idx;
    self.commands[idx] = .{ .Draw = info };
}
