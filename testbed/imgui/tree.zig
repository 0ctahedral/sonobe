//! A tree for layout and use of ui elements
const std = @import("std");
const math = @import("math");
const Vec2 = math.Vec2;
const Rect = @import("./imgui.zig").Rect;
const assert = std.debug.assert;

/// basic node in the tree
pub const Node = struct {
    /// first child of this node it there is one
    child: ?u32 = null,
    /// first sibling of this node if any
    sibling: ?u32 = null,
    /// parent of this node
    parent: u32 = ROOT_IDX,
    /// unique identifier for this node
    id: u32 = 0,

    /// size of ui element
    rect: Rect = .{},
};

/// maximum number of nodes in the tree
const MAX_NODES = 32; // 1024;
// index of the root node
const ROOT_IDX = 0;

pub const Context = struct {
    const Self = @This();
    /// the current parent index
    /// initializes to 0 as that is the root
    parent: u32 = ROOT_IDX,
    /// the last sibling index
    sibling: ?u32 = null,
};

/// keeps the nodes and root
pub const Tree = struct {
    const Self = @This();
    /// storage of child nodes
    store: [MAX_NODES]Node = undefined,

    /// next free idx
    next_idx: u32 = 1,

    ctx: Context = .{},

    pub fn init(self: *Self) void {
        self.reset();
    }

    pub fn reset(self: *Self) void {
        // reset the root node
        self.store[ROOT_IDX] = .{
            .parent = 0,
            .id = 0,
        };
    }

    pub inline fn root(self: *Self) *Node {
        return &self.store[ROOT_IDX];
    }

    pub inline fn getParent(self: *Self) *Node {
        return &self.store[self.ctx.parent];
    }

    pub inline fn getSibling(self: *Self) ?*Node {
        if (self.ctx.sibling) |idx| {
            return &self.store[idx];
        }

        return null;
    }

    /// adds a node given the current context
    /// basically just appends a sibling
    pub fn addNode(self: *Self, node: Node) u32 {
        assert(self.next_idx < MAX_NODES);
        assert(node.id != 0);

        const idx = self.next_idx;

        self.store[idx] = node;
        self.store[idx].parent = self.ctx.parent;
        self.store[idx].child = null;
        self.store[idx].sibling = null;

        // if there is already a sibling in the context, we just append
        // this node as the sibling
        if (self.getSibling()) |sib| {
            assert(sib.sibling == null);
            sib.sibling = idx;
        } else {
            assert(self.getParent().child == null);
            // otherwise this sibling is the first child
            self.getParent().child = idx;
        }

        self.ctx.sibling = idx;
        self.next_idx += 1;

        return idx;
    }

    /// adds a node with the current context and updates the parent
    /// to point to the new node
    pub fn startCtx(self: *Self, node: Node) u32 {
        const idx = self.addNode(node);

        self.ctx.parent = idx;
        self.ctx.sibling = null;

        return idx;
    }

    pub fn endCtx(self: *Self) void {
        const parent = self.getParent();

        self.ctx.sibling = if (parent.sibling) |s| s else self.ctx.parent;
        self.ctx.parent = parent.parent;
    }
};

/// walks a given tree
pub const Walker = struct {
    const Self = @This();

    ctx: Context = .{},
    current: u32 = ROOT_IDX,
    tree: *Tree,

    /// returns the parent of the current node
    /// if we are already at the root then returns null
    pub fn up(self: *Self) ?*Node {
        if (self.current == ROOT_IDX) {
            return null;
        }
        self.current = self.ctx.parent;

        self.ctx.parent = self.tree.store[self.current].parent;
        // self.ctx.sibling = self.current;
        self.ctx.sibling = null;

        return &self.tree.store[self.current];
    }
    /// returns the next node "down" if there is one
    pub fn down(self: *Self) ?*Node {
        if (self.tree.store[self.current].child) |child| {
            self.ctx.parent = self.current;
            self.ctx.sibling = null;
            self.current = child;
        } else {
            return null;
        }

        return &self.tree.store[self.current];
    }

    /// returns the next node "right" if there is one
    pub fn right(self: *Self) ?*Node {
        if (self.tree.store[self.current].sibling) |sibling| {
            self.ctx.sibling = self.current;
            self.current = sibling;
        } else {
            return null;
        }

        return &self.tree.store[self.current];
    }
};

// TYPES:
// button: has text, clickable
// checkbox: button that is on or off
// slider: changes a value
// dropdown: button that when activated has children
// container: holds other elements

const testing = std.testing;

test "add a bunch of nodes" {
    var tree = Tree{};
    tree.init();

    // check initial state
    const root = tree.getParent();
    try testing.expect(root.sibling == null);
    try testing.expect(root.child == null);

    try testing.expect(tree.ctx.parent == ROOT_IDX);
    try testing.expect(tree.ctx.sibling == null);
    try testing.expect(tree.next_idx == 1);

    // add a ndoe
    const n1 = tree.addNode(.{ .id = 5 });
    // tree state
    try testing.expect(tree.ctx.parent == ROOT_IDX);
    try testing.expect(tree.ctx.sibling.? == 1);
    try testing.expect(tree.next_idx == 2);
    // node state
    try testing.expect(root.sibling == null);
    try testing.expect(root.child.? == 1);

    _ = tree.addNode(.{ .id = 7 });
    // tree state
    try testing.expect(tree.ctx.parent == ROOT_IDX);
    try testing.expect(tree.ctx.sibling.? == 2);
    try testing.expect(tree.next_idx == 3);
    // node state
    try testing.expect(root.sibling == null);
    try testing.expect(root.child.? == 1);

    try testing.expect(tree.store[n1].sibling.? == 2);
}

test "context" {
    var tree = Tree{};
    tree.init();

    // check initial state
    const root = tree.getParent();
    try testing.expect(root.sibling == null);
    try testing.expect(root.child == null);

    try testing.expect(tree.ctx.parent == ROOT_IDX);
    try testing.expect(tree.ctx.sibling == null);
    try testing.expect(tree.next_idx == 1);

    // startContainer(1);
    //  start_dropdown(3);
    //      item(4);
    //      item(5);
    //      item(6);
    //  end_dropdown();
    //  button(2);
    // endContainer();
    //
    // root -> null [p: 0, s: _]
    //   |
    //   v
    // container1 -> null [p: 1, s: _]
    //   |^
    //   v|
    // dropdown2 [p: 2, s: _] -> b1 [p: 1, s: _]
    //   |^
    //   v|
    //   item3 [p: 1, s: _] -> item4 [p: 1, s: 3] -> item5 [p: 1, s: 4]

    // adds a node to the tree and makes it the new parent

    const c1 = tree.startCtx(.{ .id = 1 });
    try testing.expect(tree.ctx.parent == c1);
    try testing.expect(tree.ctx.sibling == null);
    try testing.expect(tree.next_idx == 2);
    {
        // start another context
        const c2 = tree.startCtx(.{ .id = 3 });
        try testing.expect(tree.store[c1].child.? == c2);
        try testing.expect(tree.ctx.parent == c2);
        try testing.expect(tree.ctx.sibling == null);
        {
            // add some nodes
            // end the context
            const n1 = tree.addNode(.{ .id = 4 });
            try testing.expect(tree.store[c2].child.? == n1);
            try testing.expect(tree.store[n1].sibling == null);
            try testing.expect(tree.ctx.parent == c2);
            try testing.expect(tree.ctx.sibling == n1);

            const n2 = tree.addNode(.{ .id = 5 });
            try testing.expect(tree.store[n1].sibling.? == n2);
            try testing.expect(tree.store[c2].child.? == n1);
            try testing.expect(tree.ctx.parent == c2);
            try testing.expect(tree.ctx.sibling == n2);

            const n3 = tree.addNode(.{ .id = 6 });
            try testing.expect(tree.store[n2].sibling.? == n3);
            try testing.expect(tree.store[n3].sibling == null);
            try testing.expect(tree.store[c2].child.? == n1);
            try testing.expect(tree.ctx.parent == c2);
            try testing.expect(tree.ctx.sibling == n3);
        }
        tree.endCtx();
        try testing.expect(tree.ctx.parent == c1);
        try testing.expect(tree.ctx.sibling == c2);
        // add a sibling button
        const b1 = tree.addNode(.{ .id = 2 });
        try testing.expect(tree.store[b1].sibling == null);
        try testing.expect(tree.store[b1].child == null);
        try testing.expect(tree.store[b1].parent == c1);
        try testing.expect(tree.store[c2].sibling.? == b1);
        try testing.expect(tree.ctx.parent == c1);
        try testing.expect(tree.ctx.sibling == b1);
    }
    // resets the current parent to this nodes parent
    tree.endCtx();
    try testing.expect(tree.ctx.parent == ROOT_IDX);
    try testing.expect(tree.ctx.sibling == c1);
}

test "walk empty" {
    var tree = Tree{};
    tree.init();

    var walker = Walker{
        .tree = &tree,
    };

    try testing.expect(walker.down() == null);
    try testing.expect(walker.right() == null);
    try testing.expect(walker.up() == null);
}

test "walk one layer" {
    var tree = Tree{};
    tree.init();

    var walker = Walker{
        .tree = &tree,
    };

    // check initial state
    const root = tree.getParent();
    const n1 = tree.addNode(.{ .id = 5 });
    const n2 = tree.addNode(.{ .id = 7 });

    try testing.expect(walker.ctx.parent == ROOT_IDX);
    try testing.expect(walker.current == ROOT_IDX);
    try testing.expect(walker.ctx.sibling == null);

    try testing.expect(walker.right() == null);
    try testing.expect(walker.current == ROOT_IDX);
    try testing.expect(walker.ctx.parent == ROOT_IDX);
    try testing.expect(walker.ctx.sibling == null);

    try testing.expect(walker.up() == null);
    try testing.expect(walker.current == ROOT_IDX);
    try testing.expect(walker.ctx.parent == ROOT_IDX);
    try testing.expect(walker.ctx.sibling == null);

    try testing.expect(walker.down().?.id == 5);
    try testing.expect(walker.current == n1);
    try testing.expect(walker.ctx.parent == ROOT_IDX);
    try testing.expect(walker.ctx.sibling == null);

    try testing.expect(walker.right().?.id == 7);
    try testing.expect(walker.current == n2);
    try testing.expect(walker.ctx.parent == ROOT_IDX);
    try testing.expect(walker.ctx.sibling.? == n1);
    try testing.expect(walker.right() == null);
    try testing.expect(walker.ctx.parent == ROOT_IDX);
    try testing.expect(walker.ctx.sibling.? == n1);
    _ = n2;

    // now back at root
    try testing.expect(@ptrToInt(walker.up().?) == @ptrToInt(root));
    try testing.expect(walker.ctx.parent == ROOT_IDX);
    try testing.expect(walker.ctx.sibling == null);

    try testing.expect(walker.up() == null);
    try testing.expect(walker.ctx.parent == ROOT_IDX);
    try testing.expect(walker.ctx.sibling == null);
}

pub fn pointIntersecNode(tree: *Tree, p: Vec2) ?*Node {
    var walker = Walker{
        .tree = tree,
    };

    // walk over the tree and look for intersections
    var last_inersection: ?*Node = null;
    var node: ?*Node = walker.down().?;

    while (node != null) {
        node = blk: {
            // interesect the node so we drill down
            if (node.?.rect.intersectPoint(p)) {
                last_inersection = node;
                // have a child, so we go down
                if (walker.down()) |d| {
                    break :blk d;
                } else {
                    // no child, so we check sibling
                    break :blk walker.right();
                }
            } else {
                // did not intersect so we look at sibling
                break :blk walker.right();
            }

            break :blk null;
        };
    }

    return last_inersection;
}

test "find point" {
    //
    //0,0 ┌──────────────┐
    //    │  container x │
    //    ├────────────|─┤
    //    │       1─┐  0 │
    //    │ ┌───────x──┐ │
    //    │ │xbutton 1 │ │
    //    │ └──────────┘ │
    //    │         2    │
    //    │ ┌───────|──┐ │
    //    │ │ buttonx2 │ │
    //    │ └──────────┘ │
    //    └──────────────┘w,h
    //            3-x
    //
    //    lets get the id the of the rect where the click occured
    //
    //    assume that all rectanges fit within eachother
    //

    // build the structure there

    var tree = Tree{};
    tree.init();

    // check initial state
    const root = tree.getParent();
    const c1 = tree.startCtx(.{
        .id = 1,
        .rect = .{ .w = 100, .h = 200 },
    });

    const n1 = tree.addNode(.{
        .id = 5,
        .rect = .{ .x = 10, .y = 50, .w = 80, .h = 40 },
    });
    const n2 = tree.addNode(.{
        .id = 7,
        .rect = .{ .x = 10, .y = 120, .w = 80, .h = 40 },
    });

    tree.endCtx();

    _ = root;
    _ = c1;
    _ = n1;
    _ = n2;

    const points = [_]Vec2{
        .{ .x = 95, .y = 5 },
        .{ .x = 25, .y = 60 },
        .{ .x = 60, .y = 160 },
        .{ .x = 200, .y = 200 },
    };

    const ptrs = [_]?*Node{
        &tree.store[c1],
        &tree.store[n1],
        &tree.store[n2],
        null,
    };

    for (points) |p, i| {
        try testing.expect(pointIntersecNode(&tree, p) == ptrs[i]);
    }
}
