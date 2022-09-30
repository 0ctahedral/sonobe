const utils = @import("utils");
const Handle = utils.Handle;
const Color = utils.Color;
/// Identifier for a device resource
/// the default values in the struct indicate a null handle
/// TODO: use enums/descs to make this descsafe
/// also make the resource an enum so we can have null handles
/// data for a draw call
/// right now it can only be indexed
pub const DrawIndexedDesc = struct {
    /// number of indices to draw
    count: u32,
    /// handle for the buffer we are drawing from
    vertex_handle: Handle(.Buffer) = .{},
    /// offsets into the vertex buffer for different attributes
    vertex_offsets: [8]u64 = [_]u64{0} ** 8,
    n_vertex_offsets: u8,
    /// handle for the index buffer we are drawing from
    index_handle: Handle(.Buffer),
    /// offset into the index buffer in bytes
    index_offset: u64 = 0,
    /// number of instances
    instance_count: u32 = 1,
    /// id of first instance
    instance_id: u32 = 0,
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
    clear_color: Color,
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
    data: []const u8,
};

/// A reference to a resource to be used in a pipeline
pub const BindingDesc = struct {
    const Type = enum {
        UniformBuffer,
        StorageBuffer,
        Texture,
        Sampler,
    };

    /// what type of resource we are binding to
    binding_type: Type,
};

/// A full pipeline for drawing!
pub const PipelineDesc = struct {
    pub const InputType = enum {
        Vec3,
        Vec2,
        f32,
        u8,
        u16,
        u32,
        u64,
    };

    pub const CullMode = enum {
        none,
        front,
        back,
        both,
    };

    pub const DepthStencilFlags = packed struct {
        depth_test_enable: bool = true,
        depth_write_enable: bool = true,
        stencil_test_enable: bool = false,
    };

    pub const MAX_STAGES = 3;
    pub const MAX_INPUTS = 8;
    pub const MAX_BINDGROUPS = 8;
    // TODO: max stages
    stages: [MAX_STAGES]?StageDesc = [_]?StageDesc{null} ** MAX_STAGES,

    /// groups of bindings we want to access from the shader
    bind_groups: [MAX_BINDGROUPS]?Handle(.BindGroup) = [_]?Handle(.BindGroup){null} ** MAX_BINDGROUPS,

    /// render pass this pipeline is going to draw with
    // render_pass: Handle(.RenderPass),

    /// the renderpass that we will use this shader in
    renderpass: Handle(.RenderPass),

    /// which faces should we cull?
    cull_mode: CullMode = .back,

    ///
    depth_stencil_flags: DepthStencilFlags = .{},

    /// is this pipeline going to render a wireframe?
    wireframe: bool = false,

    /// inputs for each vertex in the vertex stage
    vertex_inputs: [MAX_INPUTS]?InputType = [_]?InputType{null} ** MAX_INPUTS,

    /// space to reserve in shader for push constants
    /// maximum is 128 bytes
    push_const_size: u8 = 0,
};

pub const PushConstDesc = struct {
    pipeline: Handle(.Pipeline),
    size: u8,
    data: [128]u8 = [_]u8{0} ** 128,
};
