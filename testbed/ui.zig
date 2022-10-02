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
    pub fn intersectPoint(self: Rect, pos: Vec2) bool {
        return (pos.x >= self.x and
            pos.y >= self.y and
            pos.x <= self.x + self.w and
            pos.y <= self.y + self.h);
    }

    /// shrinks the rectangle on sides by amount
    pub fn shrink(self: Rect, amt: f32) Rect {
        const amt_2 = amt * 0.5;
        return .{
            .x = self.x + amt_2,
            .y = self.y + amt_2,
            .w = self.w - amt,
            .h = self.h - amt,
        };
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
    rect_type: RectType,
};

const MAX_RECTS = 1024;
const BUF_SIZE = MAX_RECTS * @sizeOf(RectData);

// way of identifying the item
pub const Id = struct {
    id: u32 = 0,
};

/// state of interaction
const Context = struct {
    /// about to interact 
    hover: u32 = 0,
    /// item that is now being interacted with
    active: u32 = 0,
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
id_counter: u32 = 0,

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
pub inline fn addRect(
    self: *Self,
    rect_type: RectType,
    rect: Rect,
    color: Color,
) void {
    self.addRectIndex(
        rect_type,
        rect,
        color,
        @intCast(u24, self.offset),
    );
}

pub fn addRectIndex(
    self: *Self,
    rect_type: RectType,
    rect: Rect,
    color: Color,
    /// custom index value, does not effect the offset in the buffer
    index: u24,
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
                .index = index,
                .rect_type = rect_type,
            }),
            @bitCast(u32, RectIndex{
                .corner = 1,
                .index = index,
                .rect_type = rect_type,
            }),
            @bitCast(u32, RectIndex{
                .corner = 2,
                .index = index,
                .rect_type = rect_type,
            }),
            @bitCast(u32, RectIndex{
                .corner = 2,
                .index = index,
                .rect_type = rect_type,
            }),
            @bitCast(u32, RectIndex{
                .corner = 3,
                .index = index,
                .rect_type = rect_type,
            }),
            @bitCast(u32, RectIndex{
                .corner = 0,
                .index = index,
                .rect_type = rect_type,
            }),
        },
    ) catch unreachable;

    self.offset += 1;
}

// helpers

fn nextId(self: *Self) u32 {
    self.id_counter += 1;
    return self.id_counter;
}

fn setActive(self: *Self, id: Id) void {
    self.ctx.active = id.id;
}

fn setHover(self: *Self, id: Id) void {
    if (self.ctx.hover == 0) {
        self.ctx.hover = id.id;
    }
}

fn isActive(self: *Self, id: Id) bool {
    return self.ctx.active == id.id;
}

fn isHover(self: *Self, id: Id) bool {
    return self.ctx.hover == id.id;
}

fn reset(self: *Self) void {
    // reset active
    self.ctx.active = 0;
    self.ctx.hover = 0;
}

// widgets

/// draw some text to the screen
pub fn text(
    self: *Self,
    /// string of text to write
    string: []const u8,
    /// bounding box of the text
    rect: Rect,
    /// the pt height of the text font
    height: f32,
    /// what color should the font be
    color: Color,
) void {
    var offset = Vec2{};
    const pos = Vec2.new(rect.x, rect.y);
    for (string) |b| {
        if (self.font_atlas.getGlyphData(
            @intCast(u32, b),
            pos.add(offset),
            height,
        )) |data| {
            // use the upper 8 bits in the index for the
            // lookup into the glyph table
            var index = @intCast(u24, self.offset);
            index |= (@intCast(u24, data.idx) << 16);

            offset.x += data.next_offset.x;

            // don't add the glyph if it would leave the bounds
            // of the textbox rectangle
            if (offset.x >= rect.w) break;

            self.addRectIndex(
                .glyph,
                data.rect,
                color,
                index,
            );
        }
    }
}

/// Style definition for a button
pub const ButtonStyle = struct {
    /// the default color of the button when it is not
    /// being interacted with
    color: Color,
    /// color of the button when the mouse hovers over it
    hover_color: Color,
    /// color of the button when it is clicked
    active_color: Color,
};

/// encapsulates data needed to draw a button
pub const ButtonDesc = struct {
    /// rectangle that describes the click and draw area
    rect: Rect,
    /// style of the button described ^^^
    style: ButtonStyle,
};

/// draw a button to the screen
/// returns if the button was clicked this frame
pub fn button(
    self: *Self,
    id: *Id,
    desc: ButtonDesc,
) bool {
    const mouse = input.getMouse();
    const left = mouse.getButton(.left);

    var result = false;
    var color = desc.style.color;

    if (id.id == 0) {
        id.*.id = self.nextId();
    }

    const is_intersect = desc.rect.intersectPoint(mouse.pos);

    // check if the cursor intersects this button
    // if it does then set to hover
    if (is_intersect) {
        self.setHover(id.*);
    }

    // check if this button is active
    if (self.isActive(id.*)) {
        if (left.action == .release) {
            // if it is then we check if the button is up and reset it
            if (self.isHover(id.*)) {
                result = true;
            }
            self.reset();
        }
        color = desc.style.active_color;
    } else if (self.isHover(id.*)) {
        // we were hovered but the mouse is no longer in
        // then reset
        if (is_intersect) {
            color = desc.style.hover_color;
            // if the mouse is down and was already hovering over this
            // then we are not active
            if (left.action == .press) {
                self.setActive(id.*);
            }
        } else {
            self.reset();
        }
    }

    self.addRect(.solid, desc.rect, color);

    return result;
}

pub const SliderStyle = struct {
    /// color for slider area
    slider_color: Color,
    /// color for slider handle
    color: Color,
    /// color of the handle when hovered over
    hover_color: Color,
    /// color of the handle when clicked or dragged
    active_color: Color,
};

pub const SliderDesc = struct {
    /// size and position of the slider
    slider_rect: Rect,
    /// width of the handle
    handle_w: f32,
    /// height of the handle
    handle_h: f32,
    /// ^^^
    style: SliderStyle,
    /// minimum value of the slider
    min: f32,
    /// maximum value of the slider
    max: f32,
    /// should the slider return true when
    /// active or only when the value chagnes?
    ret_on_active: bool = false,
};

pub fn slider(
    self: *Self,
    id: *Id,
    /// value that the slider changes
    value: *f32,
    desc: SliderDesc,
) bool {
    if (id.id == 0) {
        id.*.id = self.nextId();
    }

    var ret = false;

    const mouse = input.getMouse();
    const left = mouse.getButton(.left);
    // will change based on selection status
    var color = desc.style.color;

    const min_x = desc.slider_rect.x - desc.handle_w * 0.5;
    const max_x = desc.slider_rect.x + desc.slider_rect.w - (desc.handle_w * 0.5);

    const x = math.util.map(
        f32,
        value.*,
        desc.min,
        desc.max,
        min_x,
        max_x,
    );

    var hrect = Rect{
        .x = x,
        .y = desc.slider_rect.y + (desc.slider_rect.h - desc.handle_h) * 0.5,
        .w = desc.handle_w,
        .h = desc.handle_h,
    };

    const is_intersect = hrect.intersectPoint(mouse.pos);

    // check if the cursor intersects this button
    // if it does then set to hover
    if (is_intersect) {
        self.setHover(id.*);
    }

    // check if this button is active
    if (self.isActive(id.*)) {
        // if released we gotta reset
        if (desc.ret_on_active) {
            ret = true;
        }
        if (left.action == .release) {
            self.reset();
            ret = true;
        }
        // otherwise lets move some shit
        hrect.x += mouse.delta.x;
        hrect.x = math.util.clamp(f32, hrect.x, min_x, max_x);
        // now we need to modify value
        const new_value = math.util.map(
            f32,
            hrect.x,
            min_x,
            max_x,
            desc.min,
            desc.max,
        );
        if (new_value != value.*) {
            value.* = new_value;
            ret = true;
        }

        color = desc.style.active_color;
    } else if (self.isHover(id.*)) {
        // we were hovered but the mouse is no longer in
        // then reset
        if (is_intersect) {
            color = desc.style.hover_color;
            // if the mouse is down and was already hovering over this
            // then we are not active
            if (left.action == .press) {
                self.setActive(id.*);
            }
        } else {
            self.reset();
        }
    }

    // draw slider rect
    self.addRect(.solid, desc.slider_rect, desc.style.slider_color);
    // draw handle rect
    self.addRect(.solid, hrect, color);

    return ret;
}
