pub const Handle = struct {
    /// index of this resource
    resource: u32,
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
