const std = @import("std");
const input = @import("platform").input;

const device = @import("device");
const resources = device.resources;
const descs = device.resources.descs;
const CmdBuf = device.CmdBuf;

const utils = @import("utils");
const log = utils.log;
const Color = utils.Color;
const Handle = utils.Handle;

const math = @import("math");
const Vec2 = math.Vec2;
const Mat4 = math.Mat4;

// TODO: maybe move?
pub const Rect = packed struct {
    x: f32 = 0,
    y: f32 = 0,
    w: f32 = 0,
    h: f32 = 0,

    pub fn intersects(self: @This(), pos: Vec2) bool {
        return (pos.x >= self.x and
            pos.y >= self.y and
            pos.x <= self.x + self.w and
            pos.y <= self.y + self.h);
    }
};

const Self = @This();

const RectData = packed struct {
    rect: Rect,
    color: Color,
};

const MAX_QUADS = 1024;
const BUF_SIZE = @sizeOf(Mat4) + MAX_QUADS * @sizeOf(RectData);

// way of identifying the item
pub const Id = u32;

// state of interaction
const Context = struct {
    /// about to interact 
    hover: Id = 0,
    /// item is now being interacted with
    active: Id = 0,
};

ctx: Context = .{},
allocator: std.mem.Allocator = undefined,
group: Handle(.BindGroup) = .{},
pipeline: Handle(.Pipeline) = .{},
data_buffer: Handle(.Buffer) = .{},
idx_buffer: Handle(.Buffer) = .{},
offset: u32 = 0,

pub fn init(
    screen_pass: Handle(.RenderPass),
    allocator: std.mem.Allocator,
) !Self {
    var self = Self{};
    self.allocator = allocator;

    self.group = try resources.createBindGroup(&.{
        .{ .binding_type = .StorageBuffer },
    });

    self.data_buffer = try resources.createBuffer(
        .{
            .size = BUF_SIZE,
            .usage = .Storage,
        },
    );

    try self.onResize();

    try resources.updateBindGroup(self.group, &[_]resources.BindGroupUpdate{
        .{ .binding = 0, .handle = self.data_buffer.erased() },
    });

    self.idx_buffer = try resources.createBuffer(
        .{
            .size = MAX_QUADS * 6 * @sizeOf(u32),
            .usage = .Index,
        },
    );

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
        .depth_stencil_flags = .{ .depth_write_enable = false },
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

    return self;
}

pub fn deinit(self: *Self) void {
    _ = self;
}

pub fn update(self: *Self) !void {
    self.ctx.hover = 0;
}

pub fn onResize(self: *Self) !void {
    _ = try resources.updateBufferTyped(
        self.data_buffer,
        0,
        Mat4,
        &[_]Mat4{
            Mat4.ortho(
                0,
                @intToFloat(f32, device.w),
                0,
                @intToFloat(f32, device.h),
                -100,
                100,
            ),
        },
    );
}

pub fn draw(self: *Self, cmd: *CmdBuf) !void {
    try cmd.bindPipeline(self.pipeline);
    // draw the quads
    try cmd.drawIndexed(self.offset * 6, .{}, &.{}, self.idx_buffer, 0);

    self.offset = 0;
}

// helpers

fn addRect(
    self: *Self,
    rect: Rect,
    color: Color,
) void {
    // add the rectangle
    const Index = packed struct {
        index: u24,
        corner: u8,
    };

    _ = resources.updateBufferTyped(
        self.data_buffer,
        @sizeOf(Mat4) + (@sizeOf(RectData) * self.offset),
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
            @bitCast(u32, Index{
                .corner = 0,
                .index = @intCast(u24, self.offset),
            }),
            @bitCast(u32, Index{
                .corner = 1,
                .index = @intCast(u24, self.offset),
            }),
            @bitCast(u32, Index{
                .corner = 2,
                .index = @intCast(u24, self.offset),
            }),
            @bitCast(u32, Index{
                .corner = 2,
                .index = @intCast(u24, self.offset),
            }),
            @bitCast(u32, Index{
                .corner = 3,
                .index = @intCast(u24, self.offset),
            }),
            @bitCast(u32, Index{
                .corner = 0,
                .index = @intCast(u24, self.offset),
            }),
        },
    ) catch unreachable;

    self.offset += 1;
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

pub const ButtonDesc = struct {
    rect: Rect,
    color: Color,
    hover_color: Color,
    active_color: Color,
};

pub fn button(self: *Self, id: *Id, desc: ButtonDesc) bool {
    const mouse = input.getMouse();

    var result = false;
    var color = desc.color;

    if (id.* == 0) {
        // id.* = self.getId();
        return result;
    }

    // check if the cursor intersects this button
    // if it does then set to hover
    if (desc.rect.intersects(mouse.pos)) {
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
        color = desc.active_color;
    } else if (self.isHover(id.*)) {
        color = desc.hover_color;
        // if the mouse is down and was already hovering over this
        // then we are not active
        if (mouse.getButton(.left).action == .press) {
            self.setActive(id.*);
        }
    }

    self.addRect(desc.rect, color);

    return result;
}
