//! A tree for layout and use of ui elements
const std = @import("std");
const assert = std.debug.assert;

/// basic node in the tree
pub const Node = struct {
    /// first child of this node it there is one
    child: ?u32 = null,
    /// first sibling of this node if any
    sibling: ?u32 = null,
    /// parent of this node
    parent: u32,
    /// unique identifier for this node?
    id: u32,
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
    pub fn addNode(self: *Self, id: u32) u32 {
        assert(self.next_idx < MAX_NODES);
        assert(id != 0);

        const idx = self.next_idx;

        self.store[idx] = .{
            .id = id,
            .parent = self.ctx.parent,
        };

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
    pub fn startCtx(self: *Self, id: u32) u32 {
        const idx = self.addNode(id);

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
    const n1 = tree.addNode(5);
    // tree state
    try testing.expect(tree.ctx.parent == ROOT_IDX);
    try testing.expect(tree.ctx.sibling.? == 1);
    try testing.expect(tree.next_idx == 2);
    // node state
    try testing.expect(root.sibling == null);
    try testing.expect(root.child.? == 1);

    _ = tree.addNode(7);
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

    const c1 = tree.startCtx(1);
    try testing.expect(tree.ctx.parent == c1);
    try testing.expect(tree.ctx.sibling == null);
    try testing.expect(tree.next_idx == 2);
    {
        // start another context
        const c2 = tree.startCtx(3);
        try testing.expect(tree.store[c1].child.? == c2);
        try testing.expect(tree.ctx.parent == c2);
        try testing.expect(tree.ctx.sibling == null);
        {
            // add some nodes
            // end the context
            const n1 = tree.addNode(4);
            try testing.expect(tree.store[c2].child.? == n1);
            try testing.expect(tree.store[n1].sibling == null);
            try testing.expect(tree.ctx.parent == c2);
            try testing.expect(tree.ctx.sibling == n1);

            const n2 = tree.addNode(5);
            try testing.expect(tree.store[n1].sibling.? == n2);
            try testing.expect(tree.store[c2].child.? == n1);
            try testing.expect(tree.ctx.parent == c2);
            try testing.expect(tree.ctx.sibling == n2);

            const n3 = tree.addNode(6);
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
        const b1 = tree.addNode(2);
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
