/// This module implements actions that require the new I/O system to work correctly.
module fluid.future.action;

import fluid.node;
import fluid.tree;
import fluid.types;
import fluid.style;
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

    this() {

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
/// Using this function requires knowing the last position of the node, which isn't usually stored. Depending on
/// the usecase, you may need to use `FindFocusBoxAction` earlier.
///
/// Nodes are chosen based on semantical weight — nodes within the same container will be prioritized over
/// nodes in another. Only if the weight is the same, they will be compared based on their visual distance.
/// 
/// Params:
///     node      = Node to use as reference.
///     focusBox  = Last known `focusBox` of the node.
///     direction = Direction to switch to, if calling `focusDirection`.
/// Returns:
///     A tree action which will run during the next frame. You can attach a callback using its `then` method
///     to process the found node.
PositionalFocusAction focusAbove(Node node, Rectangle focusBox) {
    return focusDirection(node, focusBox, Style.Side.top);
}

/// ditto
PositionalFocusAction focusBelow(Node node, Rectangle focusBox) {
    return focusDirection(node, focusBox, Style.Side.bottom);
}

/// ditto
PositionalFocusAction focusToLeft(Node node, Rectangle focusBox) {
    return focusDirection(node, focusBox, Style.Side.left);
}

/// ditto
PositionalFocusAction focusToRight(Node node, Rectangle focusBox) {
    return focusDirection(node, focusBox, Style.Side.right);
}

/// ditto
PositionalFocusAction focusDirection(Node node, Rectangle focusBox, Style.Side direction) {

    auto action = new PositionalFocusAction(node, focusBox, direction);
    node.startAction(action);
    return action;

}

final class PositionalFocusAction : FocusSearchAction {

    public {

        /// Node to use as reference. The action will either select the next node that follows, or the previous.
        Node target;

        /// Focus box of the target node.
        Rectangle focusBox;

        /// Direction of search.
        Style.Side direction;

        /// Focus box of the located node.
        Rectangle resultFocusBox;

    }

    private {

        // Properties for the match
        int   resultPriority;   /// Priority assigned to the match.
        float resultDistance2;  /// Distance

        /// Priority assigned to the next node, based on the current tree position.
        int priority;

        /// Multiplier for changes to priority; +1 when moving towards the target, -1 when moving away from it.
        /// This assigns higher priority for nodes that are semantically closer to the match.
        ///
        /// Priority changes only when depth changes; if two nodes are drawn and they're siblings, priority 
        /// won't change. Priority will only change if the relation is different, e.g. child, cousin, etc.
        int priorityDirection = 1;

        /// Current depth.
        int depth;

        /// Depth of the last node drawn.
        int lastDepth;

    }

    this() {

    }

    this(Node target, Rectangle focusBox, Style.Side direction) {
        reset(target, focusBox, direction);
    }

    /// Re-arm the action.
    void reset(Node target, Rectangle focusBox, Style.Side direction) {
        this.result = null;
        this.target = target;
        this.focusBox = focusBox;
        this.direction = direction;
        this.resultFocusBox = focusBox;
        clearSubscribers();
    }

    override void beforeTree(Node node, Rectangle rectangle) {
        this.result = null;
        this.priority = 0;
        this.priorityDirection = 1;
        this.depth = 0;
        this.lastDepth = 0;
    }

    override void beforeDraw(Node node, Rectangle) {

        depth++;

    }

    override void afterDraw(Node node, Rectangle, Rectangle, Rectangle inner) {

        import std.math : abs;

        depth--;

        auto focusable = cast(Focusable) node;

        // Set priority
        priority += priorityDirection * abs(depth - lastDepth);
        lastDepth = depth;

        // Stop if priority starts sinking
        if (result && priorityDirection < 0 && priority < resultPriority) stop;

        // Ignore nodes that don't accept focus
        if (!focusable) return;

        // Found the target, reverse priority direction
        if (node.opEquals(target)) {
            priorityDirection = -1;
            return;
        }

        const box = node.focusBox(inner);
        const dist = distance2(box);

        // Compare against previous best match
        if (result) {

            // Ignore if the other match has higher priority
            if (resultPriority > priority) return;

            // If priorities are equal, compare distance
            if (resultPriority == priority
                && resultDistance2 < dist) return;

        }

        // Check if this node matches the direction
        if (box.isBeyond(focusBox, direction)) {

            // Replace the node
            result = node;
            resultPriority  = priority;
            resultDistance2 = dist;
            resultFocusBox  = box;

        }

    }

    override void stopped() {

        if (auto focusable = cast(Focusable) result) {
            focusable.focus();
        }

        super.stopped();

    }

    /// Get the square of the distance between given box and the target's `focusBox`.
    private float distance2(Rectangle box) {

        /// Get the center of given rectangle on the axis opposite to the results of getSide.
        float center(Rectangle rect) {

            return direction == Style.Side.left || direction == Style.Side.right
                ? rect.y + rect.height
                : rect.x + rect.width;

        }

        // Distance between box sides facing each other, see `checkDirection`
        const distanceExternal = focusBox.getSide(direction) - box.getSide(direction.reverse);

        /// Distance between centers of the boxes on the other axis
        const distanceOpposite = center(box) - center(focusBox);

        return distanceExternal^^2 + distanceOpposite^^2;

    }

}
