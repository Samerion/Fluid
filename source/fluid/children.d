/// This module defines the `Children` struct which will catch mutations made to it while drawing, and defines utils
/// for operating on children.
module fluid.children;

import std.range;

import fluid.node;

@safe pure:

debug struct Children {

    private enum mutateError = "Cannot mutate children list while its being rendered. This should be done in an event "
        ~ "handler, such as the mouseImpl/keyboardImpl methods.";

    private {

        Node[] _children;
        bool _isLocked;
        bool _hasChanged;

    }

    @safe:

    this(inout(Children) old) inout {

        this._children = old._children;
        this._isLocked = false;

    }

    size_t length() const {

        return _children.length;

    }

    size_t length(size_t value) {

        assert(!_isLocked, mutateError);

        _hasChanged = true;

        return _children.length = value;

    }

    bool empty() const {

        return _children.length == 0;

    }

    /// Remove the first item.
    void popFront() {

        assert(!_isLocked, mutateError);
        assert(!empty, "Can't pop an empty children list");

        _hasChanged = true;
        _children.popFront();

    }

    /// Get the first child.
    ref inout(Node) front() inout {

        assert(!empty, "Can't get the first item of an empty children list");

        return _children[0];

    }

    void opAssign(Node[] newList) {

        assert(!_isLocked, mutateError);
        _hasChanged = true;
        _children = newList;

    }

    // Indexing and slicing is allowed
    inout(Node[]) opIndex() inout {

        return _children[];

    }
    ref auto opIndex(Args...)(Args args) inout {

        return _children[args];

    }

    size_t opDollar() const {

        return _children.length;

    }

    ref Node[] getChildren() return {

        debug assert(!_isLocked, "Can't get a mutable reference to children while rendering. Consider doing this in "
            ~ "input handling methods like mouseImpl/keyboardImpl which happen after rendering is complete. But if "
            ~ "this is necessary, you may use `fluid.children.asConst` instead. Note, iterating over the (mutable) "
            ~ "children is still legal. You can also use `node.remove` if you want to simply remove a node.");
        _hasChanged = true;
        return _children;

    }

    int opApply(scope int delegate(Node node) @safe dg) {

        foreach (child; _children) {

            if (auto result = dg(child)) return result;

        }

        return 0;

    }

    int opApply(scope int delegate(size_t index, Node node) @safe dg) {

        foreach (i, child; _children) {

            if (auto result = dg(i, child)) return result;

        }

        return 0;

    }

    int opApply(scope int delegate(Node node) @system dg) @system {

        foreach (child; _children) {

            if (auto result = dg(child)) return result;

        }

        return 0;

    }

    int opApply(scope int delegate(size_t index, Node node) @system dg) @system {

        foreach (i, child; _children) {

            if (auto result = dg(i, child)) return result;

        }

        return 0;

    }

    alias getChildren this;

}

else alias Children = Node[];

static assert(isInputRange!Children);

/// Make sure the given children list hasn't changed since the dirty bit was last cleared.
void assertClean(ref Children children, lazy string message) {

    debug assert(!children._hasChanged, message);

}

/// Make sure the given children list hasn't changed since the dirty bit was last cleared.
void assertClean(ref Children children) {

    debug assert(!children._hasChanged);

}

/// Clear the dirty bit on the given children list
void clearDirty(ref Children children) {

    debug children._hasChanged = false;

}

pragma(inline)
void lock(ref Children children) {

    debug children._isLocked = true;

    assertLocked(children);

}

pragma(inline)
void unlock(ref Children children) {

    debug {

        assert(children._isLocked, "Already unlocked.");

        children._isLocked = false;

    }

}

pragma(inline)
void assertLocked(ref Children children) {

    debug assert(children._isLocked);

}

/// Get the children list as const.
pragma(inline)
const(Node[]) asConst(Children children) {

    debug return children._children;
    else  return children;

}

/// Get a reference to the children list forcefully, ignoring the lock. Doesn't set the dirty flag.
pragma(inline)
ref Node[] forceMutable(return ref Children children) @system {

    debug return children._children;
    else  return children;

}
