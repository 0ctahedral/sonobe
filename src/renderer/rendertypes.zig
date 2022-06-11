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
