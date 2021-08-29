/// This module defines the `Children` struct which will catch mutations to it made while drawing, and defines utils
/// for operating on children.
module glui.children;

import std.range;

import glui.node;

@safe pure:

debug struct Children {

    private enum mutateError = "Cannot mutate children list while its being rendered. This should be done in an event "
        ~ "handler, such as the mouseImpl/keyboardImpl methods.";

    private {

        GluiNode[] _children;
        bool _locked;

    }

    @safe:

    this(inout(Children) old) inout {

        this._children = old._children;
        this._locked = false;

    }

    @property {

        size_t length() const {

            return _children.length;

        }

        size_t length(size_t value) {

            debug assert(!_locked, mutateError);

            return _children.length = value;

        }

    }

    @property
    bool empty() const {

        return _children.length == 0;

    }

    /// Remove the first item.
    void popFront() {

        debug assert(!_locked, mutateError);
        assert(!empty, "Can't pop an empty children list");

        _children.popFront();

    }

    /// Get the first child.
    ref inout(GluiNode) front() inout {

        assert(!empty, "Can't get the first item of an empty children list");

        return _children[0];

    }

    void opAssign(GluiNode[] newList) {

        debug assert(!_locked, mutateError);
        _children = newList;

    }

    // Indexing and slicing is allowed
    GluiNode[] opIndex() {

        return _children[];

    }
    auto opIndex(Args...)(Args args) {

        return _children[args];

    }

    @property
    size_t opDollar() const {

        return _children.length;

    }

    ref GluiNode[] getChildren() return {

        debug assert(!_locked, "Can't get a mutable reference to children while rendering. Consider doing this in "
            ~ "input handling methods like mouseImpl/keyboardImpl which happen after rendering is complete. But if "
            ~ "this is necessary, you may use `glui.children.asConst` instead. Note, iterating over the (mutable) "
            ~ "children is still legal. You can also use `node.remove` if you want to simply remove a node.");
        return _children;

    }

    int opApply(int delegate(GluiNode node) @trusted dg) {

        foreach (child; _children) {

            if (auto result = dg(child)) return result;

        }

        return 0;

    }

    int opApply(int delegate(size_t index, GluiNode node) @trusted dg) {

        foreach (i, child; _children) {

            if (auto result = dg(i, child)) return result;

        }

        return 0;

    }

    alias getChildren this;

}

else alias Children = GluiNode[];

static assert(isInputRange!Children);


pragma(inline)
void lock(ref Children children) {

    debug children._locked = true;

    assertLocked(children);

}

pragma(inline)
void unlock(ref Children children) {

    debug {

        assert(children._locked, "Already unlocked.");

        children._locked = false;

    }

}

pragma(inline)
void assertLocked(ref Children children) {

    // debug just to de sure lol
    // pretty sure you can fiddle with the compiler flags enough to make this not compile
    debug assert(children._locked);

}

/// Get the children list as const.
pragma(inline)
const(GluiNode[]) asConst(Children children) {

    debug return children._children;
    else  return children;

}

/// Get a reference to the children list forcefully, ignoring the lock.
pragma(inline)
ref GluiNode[] forceMutable(return ref Children children) @system {

    debug return children._children;
    else  return children;

}

/// Get a reference to child within the parent.
///
/// This will probably be soon deprecated in favor of a "placeholder" node to fulfill this purpose.
ref GluiNode childRef(ref Children children, size_t index) @system {

    debug assert(!children._locked, "Can't get reference to a locked child.");

    debug return children._children[index];
    else  return children[index];

}
