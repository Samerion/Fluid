/// This module implements actions that require the new I/O system to work correctly.
module fluid.future.action;

import fluid.node;
import fluid.tree;
import fluid.types;
import fluid.actions;

import fluid.io.focus;

import fluid.future.pipe;

@safe:


abstract class FocusSearchAction : NodeSearchAction, Publisher!Focusable {

    protected {

        /// Event that runs when the tree action finishes.
        Event!Focusable finished;

    }

    override void clearSubscribers() {
        super.clearSubscribers();
        finished.clearSubscribers();
    }

    override void subscribe(Subscriber!Focusable subscriber) {
        finished.subscribe(subscriber);
    }

    override void stopped() {
        super.stopped();
        finished(cast(Focusable) result);
    }

}

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

final class OrderedFocusAction : TreeAction, Publisher!Focusable, Publisher!Node {

    public {

        /// Node to use as reference. The action will either select the next node that follows, or the previous.
        Node target;

        /// If true, the action finds the previous node. If false, the action finds the next one.
        bool isReverse;

        /// If true, does nothing if the target node is the last (going forward) or the first (going backwards).
        /// Otherwise goes back to the top or bottom respectively.
        bool isWrapDisabled;

    }

    protected {

        Subscriber!Focusable onFinishFocusable;
        Subscriber!Node onFinishNode;

    }

    private {

        /// Last focusable node in the branch, first focusable node in the branch. Updates as the node iterates.
        Focusable _lastFocusable, _firstFocusable;

        /// Previous and next focusable relative to the target.
        Focusable _previousFocusable, _nextFocusable;

    }

    alias then = typeof(super).then;
    alias then = Publisher!Node.then;
    alias then = Publisher!Focusable.then;

    this(Node target, bool isReverse = false, bool wrap = true) {
        reset(target, isReverse, wrap);
    }

    override void clearSubscribers() {

        super.clearSubscribers();
        this.onFinishFocusable = null;

    }

    override void subscribe(Subscriber!Focusable subscriber)
    in (onFinishFocusable is null, "Subscriber!Focusable is already connected")
    do {
        onFinishFocusable = subscriber;
    }

    override void subscribe(Subscriber!Node subscriber)
    in (onFinishNode is null, "Subscriber!Node is already connected")
    do {
        onFinishNode = subscriber;
    }

    /// Re-arm the action.
    void reset(Node target, bool isReverse = false, bool wrap = true) {
        this.target = target;
        this.isReverse = isReverse;
        this.isWrapDisabled = !wrap;
        this._lastFocusable = null;
        this._firstFocusable = null;
        this._previousFocusable = null;
        this._nextFocusable = null;
        clearSubscribers();
    }

    override void beforeDraw(Node node, Rectangle) {

        // Found the target
        if (node == target) {

            // Going backwards: Mark the last focusable as the previous node
            if (isReverse) {
                _previousFocusable = _lastFocusable;
            }

            // Going forwards: Clear the next focusable so it can be overriden by a correct value
            else {
                _nextFocusable = null;
            }

            return;

        }

        // Ignore nodes that are not focusable
        auto focusable = cast(Focusable) node;
        if (!focusable) return;

        // Set first and next node to this node
        if (_firstFocusable is null) {
            _firstFocusable = focusable;
        }
        if (_nextFocusable is null) {
            _nextFocusable = focusable;
        }

        // Mark as the last found focusable
        _lastFocusable = focusable;

    }

    /// Returns: If the action finished, the focusable that was found and focused.
    Focusable result() {

        // Selecting previous or next node
        auto result = isReverse
            ? _previousFocusable
            : _nextFocusable;

        // No such node, try first/last
        if (!isWrapDisabled && result is null) {
            result = isReverse
                ? _lastFocusable
                : _firstFocusable;
        }

        return result;

    }

    override void afterTree() {

        // Found a result!
        if (auto result = this.result) {
            result.focus();
        }

        stop;

    }

    override void stopped() {

        super.stopped();
        if (onFinishFocusable) onFinishFocusable(this.result);
        if (onFinishNode) onFinishNode(cast(Node) this.result);

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
