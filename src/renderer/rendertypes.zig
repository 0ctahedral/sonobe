pub const Handle = struct {
    /// index of this resource
    resource: u32,
};

/// data for a draw call
/// right now it can only be indexed
pub const DrawDesc = struct {
    /// number of indices to draw
    count: u32,
    /// handle for the buffer we are drawing from
    vertex_handle: Handle,
    index_handle: Handle,
};

// buffer stuff
pub const BufferDesc = struct {
    pub const Usage = enum {
        Vertex,
        Index,
        //        Storage,
        //        Uniform,
    };
    usage: Usage,
    size: usize,
};

pub const TextureDesc = struct {
    width: u32,
    height: u32,
    depth: u32 = 1,
    channels: u32,
    flags: packed struct {
        /// is this texture be transparent?
        transparent: bool = false,
        /// can this texture be written to?
        writable: bool = false,
    },
};
