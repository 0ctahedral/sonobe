const std = @import("std");
const input = @import("platform").input;

const device = @import("device");
const resources = device.resources;
const descs = device.resources.descs;
const CmdBuf = device.CmdBuf;

const utils = @import("utils");
const log = utils.log.Logger("ui");
const Color = utils.Color;
const Handle = utils.Handle;

const math = @import("math");
const Vec2 = math.Vec2;
const Mat4 = math.Mat4;

const Self = @This();

const FontAtlas = @import("./font_atlas.zig").FontAtlas;

/// A 2d rectangle
pub const Rect = packed struct {
    /// x postion
    x: f32 = 0,
    /// y postion
    y: f32 = 0,
    /// width
    w: f32 = 0,
    /// height
    h: f32 = 0,

    /// does this rectangle intersect the given point
    pub fn intersectPoint(self: @This(), pos: Vec2) bool {
        return (pos.x >= self.x and
            pos.y >= self.y and
            pos.x <= self.x + self.w and
            pos.y <= self.y + self.h);
    }
};

/// Struct of data sent to gpu for a single rectangle
const RectData = packed struct {
    rect: Rect,
    color: Color,
    // TODO: extra data?
    // or do we look that up based on the type?
};

/// the type of rectangle to encode in the buffer
const RectType = enum(u6) {
    solid,
    glyph,
};

/// data that is packed into an index sent to the gpu
const RectIndex = packed struct {
    index: u24,
    corner: u2,
    rect_type: RectType = .solid,
};

const MAX_RECTS = 1024;
const BUF_SIZE = MAX_RECTS * @sizeOf(RectData);

// way of identifying the item
pub const Id = u32;

/// state of interaction
const Context = struct {
    /// about to interact 
    hover: Id = 0,
    /// item that is now being interacted with
    active: Id = 0,
};

/// uniform data for the shader
const UniformData = struct {
    view_proj: Mat4,
};

ctx: Context = .{},

/// group of bindings for rectangle data
group: Handle(.BindGroup) = .{},
/// buffer of uniform data (e.g. camera matrix)
uniform_buffer: Handle(.Buffer) = .{},
/// buffer of rectangle declarations
rect_buffer: Handle(.Buffer) = .{},
/// buffer of indices of the rectangles to draw
idx_buffer: Handle(.Buffer) = .{},

/// shader 
pipeline: Handle(.Pipeline) = .{},

/// current offset in number of rectangles bump allocated so far
offset: u32 = 0,
/// counter for unique ids which identify the currently
/// hovering or active ui
/// TODO: may need a more robust system for this
id_counter: Id = 0,

font_atlas: FontAtlas = undefined,

allocator: std.mem.Allocator = undefined,

pub fn init(
    screen_pass: Handle(.RenderPass),
    allocator: std.mem.Allocator,
) !Self {
    var self = Self{};
    self.allocator = allocator;

    self.font_atlas = try FontAtlas.init(
        "./assets/fonts/scientifica-11.bdf",
        self.allocator,
    );

    // setup buffers

    self.uniform_buffer = try resources.createBuffer(.{
        .size = @sizeOf(UniformData),
        .usage = .Uniform,
    });

    // TODO: uniform for now but may need to be storage
    // for ui that requires more rectangles
    self.rect_buffer = try resources.createBuffer(.{
        .size = BUF_SIZE,
        .usage = .Uniform,
    });

    self.idx_buffer = try resources.createBuffer(.{
        .size = MAX_RECTS * 6 * @sizeOf(u32),
        .usage = .Index,
    });

    // setup bindgroup

    self.group = try resources.createBindGroup(&.{
        // uniform data
        .{ .binding_type = .UniformBuffer },
        // rect data
        .{ .binding_type = .UniformBuffer },
        // glyph data
        .{ .binding_type = .UniformBuffer },
        // font atlas
        .{ .binding_type = .Texture },
        // font atlas
        .{ .binding_type = .Sampler },
    });

    try resources.updateBindGroup(self.group, &[_]resources.BindGroupUpdate{
        .{ .binding = 0, .handle = self.uniform_buffer.erased() },
        .{ .binding = 1, .handle = self.rect_buffer.erased() },
        .{ .binding = 2, .handle = self.font_atlas.glyph_buffer.erased() },
        .{ .binding = 3, .handle = self.font_atlas.texture.erased() },
        .{ .binding = 4, .handle = self.font_atlas.sampler.erased() },
    });

    // create our shader pipeline

    const vert_file = try std.fs.cwd().openFile("testbed/assets/ui.vert.spv", .{ .read = true });
    defer vert_file.close();
    const frag_file = try std.fs.cwd().openFile("testbed/assets/ui.frag.spv", .{ .read = true });
    defer frag_file.close();

    const vert_data = try allocator.alloc(u8, (try vert_file.stat()).size);
    _ = try vert_file.readAll(vert_data);
    defer allocator.free(vert_data);
    const frag_data = try allocator.alloc(u8, (try frag_file.stat()).size);
    _ = try frag_file.readAll(frag_data);
    defer allocator.free(frag_data);

    var pl_desc = descs.PipelineDesc{
        .renderpass = screen_pass,
        .cull_mode = .back,
        .depth_stencil_flags = .{
            .depth_write_enable = false,
            .depth_test_enable = false,
        },
    };
    pl_desc.bind_groups[0] = self.group;
    pl_desc.stages[0] = .{
        .bindpoint = .Vertex,
        .data = vert_data,
    };
    pl_desc.stages[1] = .{
        .bindpoint = .Fragment,
        .data = frag_data,
    };

    self.pipeline = try resources.createPipeline(pl_desc);

    // update the uniform buffer

    try self.onResize();

    return self;
}

pub fn deinit(self: *Self) void {
    self.font_atlas.deinit();
}

pub fn update(self: *Self) !void {
    self.ctx.hover = 0;
}

pub fn onResize(self: *Self) !void {
    _ = try resources.updateBufferTyped(
        self.uniform_buffer,
        0,
        UniformData,
        &[_]UniformData{
            .{
                .view_proj = Mat4.ortho(
                    0,
                    @intToFloat(f32, device.w),
                    0,
                    @intToFloat(f32, device.h),
                    -100,
                    100,
                ),
            },
        },
    );
}

pub fn draw(self: *Self, cmd: *CmdBuf) !void {
    try cmd.bindPipeline(self.pipeline);
    // draw the quads
    try cmd.drawIndexed(self.offset * 6, .{}, &.{}, self.idx_buffer, 0);

    self.offset = 0;
}

/// just adds a rectangle to the buffer of geometry to draw
/// basis for all the other
pub fn addRect(
    self: *Self,
    rect_type: RectType,
    rect: Rect,
    color: Color,
) void {
    _ = resources.updateBufferTyped(
        self.rect_buffer,
        @sizeOf(RectData) * self.offset,
        RectData,
        &[_]RectData{
            .{
                .rect = rect,
                .color = color,
            },
        },
    ) catch unreachable;

    // update indices
    _ = resources.updateBufferTyped(
        self.idx_buffer,
        @sizeOf(u32) * self.offset * 6,
        u32,
        &[_]u32{
            @bitCast(u32, RectIndex{
                .corner = 0,
                .index = @intCast(u24, self.offset),
                .rect_type = rect_type,
            }),
            @bitCast(u32, RectIndex{
                .corner = 1,
                .index = @intCast(u24, self.offset),
                .rect_type = rect_type,
            }),
            @bitCast(u32, RectIndex{
                .corner = 2,
                .index = @intCast(u24, self.offset),
                .rect_type = rect_type,
            }),
            @bitCast(u32, RectIndex{
                .corner = 2,
                .index = @intCast(u24, self.offset),
                .rect_type = rect_type,
            }),
            @bitCast(u32, RectIndex{
                .corner = 3,
                .index = @intCast(u24, self.offset),
                .rect_type = rect_type,
            }),
            @bitCast(u32, RectIndex{
                .corner = 0,
                .index = @intCast(u24, self.offset),
                .rect_type = rect_type,
            }),
        },
    ) catch unreachable;

    self.offset += 1;
}

// helpers

fn getId(self: *Self) Id {
    self.id_counter += 1;
    return self.id_counter;
}

fn setActive(self: *Self, id: Id) void {
    self.ctx.active = id;
}

fn setHover(self: *Self, id: Id) void {
    if (self.ctx.hover == 0) {
        self.ctx.hover = id;
    }
}

fn isActive(self: *Self, id: Id) bool {
    return self.ctx.active == id;
}

fn isHover(self: *Self, id: Id) bool {
    return self.ctx.hover == id;
}

fn reset(self: *Self) void {
    // reset active
    self.ctx.active = 0;
    self.ctx.hover = 0;
}

// widgets

pub fn text(
    self: *Self,
    string: []const u8,
    /// TODO: replacee with bounding rect
    /// position of bottom left corner
    pos: Vec2,
    /// font height in pixels 
    height: f32,
    color: Color,
) void {
    var offset = Vec2{};
    var max_y = height;
    for (string) |b| {
        // increase x offset by width of previous glyph
        var o = Vec2{};
        if (self.font_atlas.getGlyphData(
            @intCast(u32, b),
            pos.add(offset),
            height,
        )) |data| {
            self.addRect(.glyph, data.rect, color);
            o = data.next_offset;
        }
        offset.x += o.x;
        max_y = @maximum(max_y, height + o.y);
    }

    offset.y = max_y;
}

pub const ButtonStyle = struct {
    color: Color,
    hover_color: Color,
    active_color: Color,
};

pub fn button(
    self: *Self,
    id: *Id,
    rect: Rect,
    style: ButtonStyle,
) bool {
    const mouse = input.getMouse();

    var result = false;
    var color = style.color;

    if (id.* == 0) {
        id.* = self.getId();
    }

    // check if the cursor intersects this button
    // if it does then set to hover
    if (rect.intersectPoint(mouse.pos)) {
        self.setHover(id.*);
    }

    // check if this button is active
    if (self.isActive(id.*)) {
        if (mouse.getButton(.left).action == .release) {
            // if it is then we check if the button is up and reset it
            if (id.* == self.ctx.hover) {
                result = true;
            }
            self.reset();
        }
        color = style.active_color;
    } else if (self.isHover(id.*)) {
        color = style.hover_color;
        // if the mouse is down and was already hovering over this
        // then we are not active
        if (mouse.getButton(.left).action == .press) {
            self.setActive(id.*);
        }
    }

    self.addRect(.solid, rect, color);

    return result;
}
