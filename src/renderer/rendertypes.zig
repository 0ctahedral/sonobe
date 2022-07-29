/// Identifier for a device resource
/// the default values in the struct indicate a null handle
pub const Handle = struct {
    /// index of this resource
    resource: u32 = 0,
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
        Storage,
        Uniform,
    };
    usage: Usage,
    size: usize,
};

pub const TextureDesc = struct {
    pub const Type = enum {
        @"2d",
        cubemap,
    };
    width: u32,
    height: u32,
    depth: u32 = 1,
    channels: u8,
    flags: packed struct {
        /// is this texture be transparent?
        transparent: bool = false,
        /// can this texture be written to?
        writable: bool = false,
    },
    texture_type: Type,
};

pub const SamplerDesc = struct {
    pub const Filter = enum {
        /// grab the nearest texel to the sample
        nearest,
        /// sample four nearest texels
        bilinear,
        /// sample four nearest texels on two mip map levels
        trilinear,
        /// ???
        anisotropic,
    };

    pub const Repeat = enum {
        /// wrap the texure by repeating (tiled)
        wrap,
        /// doesn't tile
        clamp,
    };

    pub const Compare = enum {
        never,
        less,
        less_eq,
        greater,
        greater_eq,
    };

    /// how should the texture be filtered when sampled
    filter: Filter,

    /// how the texture is repeated with uvs outside the range
    repeat: Repeat,

    /// how the sampler should compare mipmap values
    compare: Compare,
};

// TODO: add more details like attachments and subpasses and stuff
pub const RenderPassDesc = struct {
    pub const ClearFlags = packed struct {
        color: bool = false,
        depth: bool = false,
        stencil: bool = false,
    };
    /// color this renderpass should clear the rendertarget to
    clear_color: [4]f32,
    /// value the renderpass should clear the rendertarget depth bufffer to
    clear_depth: f32,
    /// value the renderpass should clear the rendertarget stencil buffer to
    clear_stencil: u32,
    /// flags for which values should actully be cleared
    clear_flags: ClearFlags,
};

/// Describes a shader pipeline for drawing
pub const StageDesc = struct {
    bindpoint: enum {
        Vertex,
        Fragment,
    },
    path: []const u8,
};

/// A reference to a resource to be used in a pipeline
pub const BindingDesc = struct {
    const Type = enum {
        Buffer,
        Texture,
        Sampler,
    };

    /// what type of resource we are binding to
    binding_type: Type,
};

/// A full pipeline for drawing!
pub const PipelineDesc = struct {
    const InputType = enum {
        Vec3,
        Vec2,
        f32,
        u8,
        u16,
        u32,
        u64,
    };
    const CullMode = enum {
        none,
        front,
        back,
        both,
    };
    /// render pass this pipeline is going to draw with
    // render_pass: Handle,
    stages: []const StageDesc = undefined,

    /// 
    binding_groups: []const Handle = &.{},

    renderpass: Handle,

    cull_mode: CullMode = .back,

    wireframe: bool = false,

    inputs: []const InputType = &.{},
};
