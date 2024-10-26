/// This is a simplified stack implementation optimized to reuse the nodes it creates.
///
/// Fluid uses stacks to iterate through tree structures such as `Rope` or `TextRulerCache`. The ability to quickly 
/// create new stack items is crucial to their performance, and as such avoiding allocations is a must. For this reason,
/// nodes are reused whenever possible, instead of being reclaimed by the GC.
module fluid.text.stack;

version (unittest)
    version = Fluid_EnableStackStatistics;

/// Implementation of a stack optimized to reduce allocations.
///
/// Removing nodes from the stack using `pop` or `clear` will move them to a global stack of "free" nodes. 
/// The next time an item is added to the stack, it will reuse one of these previously freed nodes. This recycling 
/// mechanism makes it possible to significantly reduce the number of allocations as the program continues.
///
/// If version `Fluid_MemoryStatistics` is set, `Stack` will count the number of total nodes it has allocated per 
/// type and thread and expose then through `totalNodeCount`.
struct Stack(T) {

    private {

        /// All stack nodes that are not currently in use.
        static StackNode!T* _trash;

        version (Fluid_EnableStackStatistics)
            static int _totalNodeCount;

        /// Top of the stack.
        StackNode!T* _top;

        /// Bottom of the stack, used to quickly transfer all nodes to the stack with `clear`.
        /// Warning: Bottom isn't cleared on `pop`, so it doesn't have to be null when empty.
        StackNode!T* _bottom;

    }

    this(T item) {
        // Stack could support batch operations so this would take a variadic argument
        push(item);
    }

    ~this() {
        clear();
    }

    version (Fluid_EnableStackStatistics) {

        /// This special field is only available when version `Fluid_MemoryStatistics` is set. `Stack` will then count 
        /// the number of total nodes it has allocated per type and thread.
        /// 
        /// This count can be reset with `resetNodeCount`.
        /// 
        /// Returns: Total number of nodes allocated by the stack.
        static int totalNodeCount() {
            return _totalNodeCount;
        }

        /// Reset `totalNodeCount` back to 0.
        static void resetNodeCount() {
            _totalNodeCount = 0;
        }

    }

    /// Returns: True if the stack is empty.
    bool empty() const {
        return _top is null;
    }

    alias back = top;
    alias removeBack = pop;

    /// Returns: The item at the top of this stack.
    ref inout(T) top() inout
    in (!empty, "Nothing is at the top of the stack when it is empty")
    do {
        return _top.item;
    }

    /// Add an item to the stack.
    /// Params:
    ///     item = Item to add to the top of the stack.
    void push(T item) {
        _top = getNode(_top, item);
        assert(_top !is _top.next, "A node must not be trashed while still in use");

        // Mark this as the bottom, if it is so
        if (_top.next is null) {
            _bottom = _top;
            assert(_bottom.next is null);
        }
    }

    /// Remove the item at the top of the stack.
    /// Returns: The item that was removed.
    T pop()
    in (!empty, "`pop` cannot operate on an empty stack")
    do {

        auto node = _top;

        assert(node !is _trash, "Node was already trashed. Was the Stack duplicated?");

        // Remove the node from the stack
        _top = node.next;

        // Trash the node
        node.next = _trash;
        _trash = node;

        return node.item;

    }

    /// Empty the stack.
    ///
    /// Done automatically when the stack leaves the scope.
    void clear()
    out (; empty)
    do {

        // Already empty, nothing to do
        if (empty) return;

        // Trash the bottom
        _bottom.next = _trash;
        _trash = _top;
        _top = null;

    }

    /// Params:
    ///     item = Item that will be pushed to the top of the stack.
    void opOpAssign(string op : "~")(T item) {

        push(item);

    }

    /// Returns:
    ///     A range that allows iterating on the range without removing any items from it. While the range functions,
    ///     items cannot be removed from the stack, or the range may break, possibly crashing the program. 
    StackRange!T opIndex() @system {

        return StackRange!T(_top);

    }

    private StackNode!T* getNode(StackNode!T* next, T item) {

        // Trash is empty, allocate
        if (_trash is null) {
            version (Fluid_EnableStackStatistics) {
                _totalNodeCount++;
            }
            auto node = new StackNode!T(next, item);
            return node;
        }

        // Take an item from the trash
        else {
            auto node = _trash;
            _trash = node.next;
            *node = StackNode!T(next, item);
            return node;
        }

    }

}

/// A StackRange can be used to iterate a stack (starting from top, going to bottom) without modifying it.
///
/// The stack cannot be modified while it has any range attached to it.
struct StackRange(T) {

    private StackNode!T* node;
    @disable this();

    private this(StackNode!T* node) {
        this.node = node;
    }

    /// Returns: True if the range has been emptied.
    bool empty() const @system {
        return node is null;
    }

    /// Returns: The item at the top of this range.
    ref inout(T) front() inout @system
    in (!empty, "Cannot use `front` of an empty range")
    do {
        return node.item;
    }

    /// Advance to the next item of the range.
    void popFront() @system
    in (!empty, "Cannot use `popFront` on an empty range")
    do {
        node = node.next;
    }

}

private struct StackNode(T) {

    StackNode* next;
    T item;

}

version (unittest) {

    /// Struct for testing the stack.
    private struct Test { 
        int value; 
        alias value this;
    }

}

@("Stack functions correctly")
unittest {

    Stack!Test stack;
    stack._trash = null;
    assert(stack.empty);
    stack.push(Test(1));
    assert(stack.top == 1);
    assert(stack._top.next is null);
    stack.push(Test(2));
    assert(stack.top == 2);
    assert(stack._top.next !is null);
    stack.push(Test(3));
    assert(stack.top == 3);
    assert(stack.pop() == 3);
    assert(stack.pop() == 2);
    assert(stack.pop() == 1);
    assert(stack.empty);

    assert(stack._trash !is null);
    assert(*stack.getNode(null, Test(1)) == StackNode!Test(null, Test(1)));
    assert(*stack.getNode(null, Test(2)) == StackNode!Test(null, Test(2)));
    assert(*stack.getNode(null, Test(3)) == StackNode!Test(null, Test(3)));
    assert(stack._trash is null);
    assert(Stack!Test.totalNodeCount == 3);
    Stack!Test.resetNodeCount();
    
}

@("Stack recycles nodes")
unittest {

    Stack!Test stack;
    stack._trash = null;
    stack ~= Test(1);
    stack ~= Test(2);
    stack ~= Test(3);
    assert(stack._trash is null);
    assert(stack._bottom !is null);
    assert(Stack!Test.totalNodeCount == 3);

    auto nodes = [stack._top, stack._top.next, stack._top.next.next];

    auto top = stack._top;

    // Clear to destroy the stack
    stack.clear();
    assert(stack.empty);
    assert(stack._trash is top);
    assert(stack._trash == nodes[0]);
    assert(stack._trash.next == nodes[1]);
    assert(stack._trash.next.next == nodes[2]);

    stack ~= Test(4);
    stack ~= Test(5);
    stack ~= Test(6);
    assert(Stack!Test.totalNodeCount == 3);
    assert(stack._trash is null);
    assert(stack._top == nodes[2]);
    assert(stack._top.next == nodes[1]);
    assert(stack._top.next.next == nodes[0]);
    assert(stack.pop() == 6);
    assert(stack.pop() == 5);
    assert(stack.pop() == 4);

    stack._trash = null;
    assert(Stack!Test.totalNodeCount == 3);
    Stack!Test.resetNodeCount();

}

@("Multiple stacks can share resources")
unittest {

    Stack!Test a;
    Stack!Test b;

    assert(Stack!Test.totalNodeCount == 0);
    assert(a._trash is null);
    assert(b._trash is null);

    a ~= Test(1);
    a ~= Test(2);
    b ~= Test(3);
    b ~= Test(4);

    assert(Stack!Test.totalNodeCount == 4);

    assert(a.pop() == 2);
    assert(a._trash !is null);

    auto freed = a._trash;

    b ~= Test(5);
    assert(b._top is freed);
    assert(a._trash is null);
    assert(Stack!Test.totalNodeCount == 4);

    {
        Stack!Test c;
        c ~= Test(6);
        c ~= Test(7);
        c ~= Test(8);
        c ~= Test(9);
    }
    assert(Stack!Test.totalNodeCount == 8);
    assert(a._trash !is null);

    a.clear();
    b.clear();

    foreach (i; 10..18) {
        a ~= Test(i);
    }
    assert(Stack!Test.totalNodeCount == 8);
    a ~= Test(18);
    assert(Stack!Test.totalNodeCount == 9);

    a.clear();
    Stack!Test.resetNodeCount();
    Stack!Test._trash = null;

}

@("Stack can be used with Range API")
unittest {

    import std.algorithm;

    assert(Stack!Test.totalNodeCount == 0);
    assert(Stack!Test._trash is null);

    Stack!Test stack;
    stack ~= Test(1);
    stack ~= Test(2);
    stack ~= Test(3);
    stack ~= Test(4);
    stack ~= Test(5);

    assert(Stack!Test.totalNodeCount == 5);
    assert(stack[].equal([5, 4, 3, 2, 1]));
    assert(Stack!Test.totalNodeCount == 5);

    assert(stack.pop() == Test(5));
    assert(stack.pop() == Test(4));
    assert(stack.pop() == Test(3));
    assert(stack.pop() == Test(2));
    assert(stack.pop() == Test(1));
    assert(stack.empty());

    assert(Stack!Test.totalNodeCount == 5);
    Stack!Test.resetNodeCount();
    Stack!Test._trash = null;

}
