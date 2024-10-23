/// This is a simplified stack implementation optimized to reuse the nodes it creates.
///
/// Fluid uses stacks to iterate through tree structures such as `Rope` or `TextRulerCache`. The ability to quickly 
/// create new stack items is crucial to their performance, and as such avoiding allocations is a must. For this reason,
/// nodes are reused whenever possible, instead of being reclaimed by the GC.
module fluid.text.stack;

/// Implementation of a stack optimized to reduce allocations.
///
/// Removing nodes from the stack using `pop` or `clear` will move them to a global stack of "free" nodes. 
/// The next time an item is added to the stack, it will reuse one of these previously freed nodes. This recycling 
/// mechanism makes it possible to significantly reduce the number of allocations as the program continues.
struct Stack(T) {

    private {

        /// All stack nodes that are not currently in use.
        static StackNode!T* _trash;

        /// Top of the stack.
        StackNode!T* _top;

    }

    /// The stack cannot be copied. Wrap it in a reference counted stack.
    @disable this(const Stack);

    /// Returns: True if the stack is empty.
    bool empty() const {
        return _top is null;
    }

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
    }

    /// Remove the item at the top of the stack.
    /// Returns: The item that was removed.
    T pop()
    in (!empty, "`pop` cannot operate on an empty stack")
    do {

        // Reclaim the node
        auto node = _top;

        // Remove the node from the stack
        _top = node.next;

        // Trash the node
        node.next = _trash;
        _trash = node;

        return node.item;

    }

    /// Params:
    ///     item = Item that will be pushed to the top of the stack.
    void opOpAssign(string op : "~")(T item) {

        push(item);

    }

    private StackNode!T* getNode(StackNode!T* next, T item) {

        // Trash is empty, allocate
        if (_trash is null) {
            return new StackNode!T(next, item);
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

private struct StackNode(T) {

    StackNode* next;
    T item;

}

unittest {

    Stack!int stack;
    stack._trash = null;
    assert(stack.empty);
    stack.push(1);
    assert(stack.top == 1);
    assert(stack._top.next is null);
    stack.push(2);
    assert(stack.top == 2);
    assert(stack._top.next !is null);
    stack.push(3);
    assert(stack.top == 3);
    assert(stack.pop() == 3);
    assert(stack.pop() == 2);
    assert(stack.pop() == 1);
    assert(stack.empty);

    assert(stack._trash !is null);
    assert(*stack.getNode(null, 1) == StackNode!int(null, 1));
    assert(*stack.getNode(null, 2) == StackNode!int(null, 2));
    assert(*stack.getNode(null, 3) == StackNode!int(null, 3));
    assert(stack._trash is null);
    
}
