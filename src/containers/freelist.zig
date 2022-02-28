/// areana allocated free list
pub const FreeList = struct {
    // TODO: types for the output and stuff

    const T = u32;

    /// size in bytes of our blocks
    const block_size = @sizeOf(u32);

    /// underlying storage
    store: []u8 align(block_size),

    const Self = @This();

    /// initialize with storage
    pub fn init(storage: []u8) Self {
        return .{
            .store = @ptrCast([]align(block_size) u8, storage),
        };
    }

    pub fn alloc(self: *Self) !*T {

    }

    pub fn deinit(self: Self) void {
        _ = self;
    }
};

test "" {
    var fl = FreeList.init();

    try fl.alloc();
}
