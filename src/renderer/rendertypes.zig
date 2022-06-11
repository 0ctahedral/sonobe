pub const Handle = struct {
    /// index of this resource
    resource: u32,
};

// buffer stuff
pub const BufferDesc = struct {
    const Kind = enum {
        Vertex,
    };
    kind: Kind,
};
