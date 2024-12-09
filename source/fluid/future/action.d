/// This module implements actions that require the new I/O system to work correctly.
module fluid.future.action;

import fluid.node;
import fluid.tree;
import fluid.types;
import fluid.actions;

import fluid.io.focus;

import fluid.future.pipe;

@safe:


/// Focus next or previous focusable node relative to the point of reference. 
/// This function only works with nodes compatible with the new I/O system introduced in Fluid 0.7.2.
///
/// Params:
///     node   = Node to use for reference.
///     branch = Branch to search. Nodes that are not children of this node will not be matched. 
///         Default to the whole tree.
///     wrap   = If true, if no node remains to focus, focus the first or last node found.
OrderedFocusAction focusNext(Node node, bool wrap = true) {
    auto action = new OrderedFocusAction(node, false, wrap);
    node.tree.queueAction(action);
    return action;
}

/// ditto
OrderedFocusAction focusPrevious(Node node, bool wrap = true) {
    auto action = new OrderedFocusAction(node, true, wrap);
    node.tree.queueAction(action);
    return action;
}

/// ditto
OrderedFocusAction focusNext(Node node, Node branch, bool wrap = true) {
    auto action = new OrderedFocusAction(node, false, wrap);
    branch.queueAction(action);
    return action;
}

/// ditto
OrderedFocusAction focusPrevious(Node node, Node branch, bool wrap = true) {
    auto action = new OrderedFocusAction(node, true, wrap);
    branch.queueAction(action);
    return action;
}

final class OrderedFocusAction : FocusSearchAction {

    public {

        /// Node to use as reference. The action will either select the next node that follows, or the previous.
        Node target;

        /// If true, the action finds the previous node. If false, the action finds the next one.
        bool isReverse;

        /// If true, does nothing if the target node is the last (going forward) or the first (going backwards).
        /// Otherwise goes back to the top or bottom respectively.
        bool isWrapDisabled;

    }

    private {

        /// Last focusable node in the branch, first focusable node in the branch. Updates as the node iterates.
        Node _last, _first;

        /// Previous and next focusable relative to the target.
        Node _previous, _next;

    }

    this(Node target, bool isReverse = false, bool wrap = true) {
        reset(target, isReverse, wrap);
    }

    /// Re-arm the action.
    void reset(Node target, bool isReverse = false, bool wrap = true) {
        this.target = target;
        this.isReverse = isReverse;
        this.isWrapDisabled = !wrap;
        clearSubscribers();
    }

    override void beforeTree(Node node, Rectangle rect) {

        super.beforeTree(node, rect);
        this._last = null;
        this._first = null;
        this._previous = null;
        this._next = null;

    }

    override void beforeDraw(Node node, Rectangle) {

        // Found the target
        if (node == target) {

            // Going backwards: Mark the last focusable as the previous node
            if (isReverse) {
                _previous = _last;
            }

            // Going forwards: Clear the next focusable so it can be overriden by a correct value
            else {
                _next = null;
            }

            return;

        }

        // Ignore nodes that are not focusable
        if (!cast(Focusable) node) return;

        // Set first and next node to this node
        if (_first is null) {
            _first = node;
        }
        if (_next is null) {
            _next = node;
        }

        // Mark as the last found focusable
        _last = node;

    }

    override void afterTree() {

        // Selecting previous or next node
        result = isReverse
            ? _previous
            : _next;

        // No such node, try first/last
        if (!isWrapDisabled && result is null) {
            result = isReverse
                ? _last
                : _first;
        }

        // Found a result!
        if (auto focusable = cast(Focusable) result) {
            focusable.focus();
        }

        stop;

    }

}


/// Find and focus a focusable node based on its visual position; above, below, to the left or to the right 
/// of a chosen node.
///
/// Nodes are chosen based on semantical position — nodes within the same container will be prioritized over
/// nodes in another.
/// 
///
PositionalFocusAction focusAbove(Node node) {

    auto action = new PositionalFocusAction;
    node.startAction(action);
    return action;

}

final class PositionalFocusAction : TreeAction {

}
