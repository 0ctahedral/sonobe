test "init" {
    // or should these be a handle type??
    const Index = u32;
    const Item = i32;
    const Set = SparseSet(Index, Item);
    const capacity = 10;
    var s: Set = Set.init(capacity, allocator);

    // indices: [  1 _ _ ...] capacity
    //             |_|
    //               v
    // items:   [ _ -5 _ ...] capacity
    s.set(1, -5);
}
