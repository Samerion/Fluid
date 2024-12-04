/// Definitions for common tree actions; This is the Fluid tree equivalent to std.algorithm.
module fluid.actions;

import fluid.node;
import fluid.tree;
import fluid.input;
import fluid.scroll;
import fluid.backend;


@safe:


/// Set focus on the given node, if focusable, or the first of its focusable children. This will be done lazily during
/// the next draw. If calling `focusRecurseChildren`, the subject of the call will be excluded from taking focus.
/// Params:
///     parent = Container node to search in.
FocusRecurseAction focusRecurse(Node parent) {

    auto action = new FocusRecurseAction;

    // Perform a tree action to find the child
    parent.queueAction(action);

    return action;

}

unittest {

    import fluid.space;
    import fluid.label;
    import fluid.button;

    auto io = new HeadlessBackend;
    auto root = vspace(
        label(""),
        button("", delegate { }),
        button("", delegate { }),
        button("", delegate { }),
    );

    // First paint: no node focused
    root.io = io;
    root.draw();

    assert(root.tree.focus is null, "No focus assigned on the first frame");

    io.nextFrame;

    // Recurse into the tree to focus on the first node
    root.focusRecurse();
    root.draw();

    assert(root.tree.focus.asNode is root.children[1], "First child is now focused");
    assert((cast(FluidFocusable) root.children[1]).isFocused);

}

/// ditto
FocusRecurseAction focusRecurseChildren(Node parent) {

    auto action = new FocusRecurseAction;
    action.excludeStartNode = true;
    parent.queueAction(action);

    return action;

}

/// ditto
FocusRecurseAction focusChild(Node parent) {

    return focusRecurseChildren(parent);

}

unittest {

    import fluid.space;
    import fluid.button;

    auto io = new HeadlessBackend;
    auto root = vframeButton(
        button("", delegate { }),
        button("", delegate { }),
        delegate { }
    );

    root.io = io;

    // Typical focusRecurse call will focus the button
    root.focusRecurse;
    root.draw();

    assert(root.tree.focus is root);

    io.nextFrame;

    // If we want to make sure the action descends below the root, we must
    root.focusRecurseChildren;
    root.draw();

    assert(root.tree.focus.asNode is root.children[0]);

}

class FocusRecurseAction : TreeAction {

    public {

        bool excludeStartNode;
        void delegate(FluidFocusable) @safe finished;

    }

    override void beforeDraw(Node node, Rectangle) {

        // Ignore if the branch is disabled
        if (node.isDisabledInherited) return;

        // Ignore the start node if excluded
        if (excludeStartNode && node is startNode) return;

        // Check if the node is focusable
        if (auto focusable = cast(FluidFocusable) node) {

            // Give it focus
            focusable.focus();

            // Submit the result
            if (finished) finished(focusable);

            // We're done here
            stop;

        }

    }

}

/// Scroll so the given node becomes visible.
/// Params:
///     node = Node to scroll to.
///     alignToTop = If true, the top of the element will be aligned to the top of the scrollable area.
ScrollIntoViewAction scrollIntoView(Node node, bool alignToTop = false) {

    auto action = new ScrollIntoViewAction;
    node.queueAction(action);
    action.alignToTop = alignToTop;

    return action;

}

/// Scroll so that the given node appears at the top, if possible.
ScrollIntoViewAction scrollToTop(Node node) {

    return scrollIntoView(node, true);

}

unittest {

    import fluid;
    import std.math;
    import std.array;
    import std.range;
    import std.algorithm;

    const viewportHeight = 10;

    auto io = new HeadlessBackend(Vector2(10, viewportHeight));
    auto root = vscrollFrame(
        layout!(1, "fill"),
        nullTheme,

        label("a"),
        label("b"),
        label("c"),
    );

    root.io = io;
    root.scrollBar.width = 0;  // TODO replace this with scrollBar.hide()

    // Prepare scrolling
    // Note: Changes made when scrolling will be visible during the next frame
    root.children[1].scrollIntoView;
    root.draw();

    auto getPositions() {
        return io.textures.map!(a => a.position).array;
    }

    // Find label positions
    auto positions = getPositions();

    // No theme so everything is as compact as it can be: the first label should be at the very top
    assert(positions[0].y.isClose(0));

    // It is reasonable to assume the text will be larger than 10 pixels (viewport height)
    // Other text will not render, since it's offscreen
    assert(positions.length == 1);

    io.nextFrame;
    root.draw();

    // TODO Because the label was hidden below the viewport, Fluid will align the bottom of the selected node with the
    // viewport which probably isn't appropriate in case *like this* where it should reveal the top of the node.
    auto texture1 = io.textures.front;
    assert(isClose(texture1.position.y + texture1.height, viewportHeight));
    assert(isClose(root.scroll, (root.scrollMax + 10) * 2/3 - 10));

    io.nextFrame;
    root.draw();

    auto scrolledPositions = getPositions();

    // TODO more tests. Scrolling while already in the viewport, scrolling while partially out of the view, etc.

}

class ScrollIntoViewAction : TreeAction {

    public {

        /// If true, try to display the child at the top.
        bool alignToTop;

    }

    private {

        /// The node this action attempts to put into view.
        Node target;

        Vector2 viewport;
        Rectangle childBox;

    }

    void reset(bool alignToTop = false) {

        this.toStop = false;
        this.alignToTop = alignToTop;

    }

    override void afterDraw(Node node, Rectangle, Rectangle paddingBox, Rectangle contentBox) {

        // Target node was drawn
        if (node is startNode) {

            // Make sure the action reaches the end of the tree
            target = node;
            startNode = null;

            // Get viewport size
            viewport = node.tree.io.windowSize;

            // Get the node's padding box
            childBox = node.focusBoxImpl(contentBox);


        }

        // Ignore children of the target node
        // Note: startNode is set until reached
        else if (startNode !is null) return;

        // Reached a scroll node
        // TODO What if the container isn't an ancestor
        else if (auto scrollable = cast(FluidScrollable) node) {

            // Perform the scroll
            childBox = scrollable.shallowScrollTo(target, paddingBox, childBox);

            // Aligning to top, make sure the child aligns with the parent
            if (alignToTop && childBox.y > paddingBox.y) {

                const offset = childBox.y - paddingBox.y;

                scrollable.scroll = scrollable.scroll + cast(size_t) offset;

            }

        }

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

final class OrderedFocusAction : TreeAction {

    import fluid.io.focus;

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
        Focusable _lastFocusable, _firstFocusable;

        /// Previous and next focusable relative to the target.
        Focusable _previousFocusable, _nextFocusable;

    }

    this(Node target, bool isReverse = false, bool wrap = true) {
        reset(target, isReverse, wrap);
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

    override void afterTree() {

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

        // Found a result!
        if (result) {
            result.focus();
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

}

final class PositionalFocusAction : TreeAction {

}
