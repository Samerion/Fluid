module fluid.io.focus;

import std.math;

import fluid.node;
import fluid.types;

import fluid.io.hover;

import fluid.tree.action;

@safe:

/// An interface to be implemented by all nodes that can take focus.
///
/// Note: Input nodes often have many things in common. If you want to create an input-taking node, you're likely better
/// off extending from `FluidInput`.
interface FluidFocusable : FluidHoverable {

    /// Handle input. Called each frame when focused.
    bool focusImpl();

    /// Set focus to this node.
    ///
    /// Implementation would usually assign `tree.focus` to self for this to take effect. It is legal, however, for this
    /// method to redirect the focus to another node (by calling its `focus()` method), or ignore the request.
    void focus();

    /// Check if this node has focus. Recommended implementation: `return tree.focus is this`. Proxy nodes, such as
    /// `FluidFilePicker` might choose to return the value of the node they hold.
    bool isFocused() const;

    /// Run input actions for the node.
    ///
    /// Internal. `Node` calls this for the focused node every frame, falling back to `keyboardImpl` if this returns
    /// false.
    final bool runFocusInputActions() {

        return this.runInputActionsImpl(false);

    }

}

/// This struct is used to track nodes in relation to each other to pass focus using the tab or arrow keys.
struct FocusDirection {

    import fluid.style;

    struct WithPriority {

        /// Pick priority based on tree distance from the focused node.
        int priority;

        /// Square of the distance between this node and the focused node.
        float distance2;

        /// The node.
        FluidFocusable node;

        alias node this;

    }

    /// Available space box of the focused item after last frame.
    Rectangle lastFocusBox;

    /// Nodes that may get focus with tab navigation.
    FluidFocusable previous, next;

    /// First and last focusable nodes in the tree.
    FluidFocusable first, last;

    /// Focusable nodes, by direction from the focused node.
    WithPriority[4] positional;

    /// Focus priority for the currently drawn node.
    ///
    /// Increased until the focused node is found, decremented afterwards. As a result, values will be the highest for
    /// nodes near the focused one. Changes with tree depth rather than individual nodes.
    int priority;

    private {

        /// Value `prioerity` is summed with on each step. `1` before finding the focused node, `-1` after.
        int priorityDirection = 1;

        /// Current tree depth.
        uint depth;

    }

    /// Update focus info with the given node. Automatically called when a node is drawn, shouldn't be called manually.
    ///
    /// `previous` will be the last focusable node encountered before the focused node, and `next` will be the first one
    /// after. `first` and `last will be the last focusable nodes in the entire tree.
    ///
    /// Params:
    ///     current = Node to update the focus info with.
    ///     box     = Box defining node boundaries (focus box)
    ///     depth   = Current tree depth. Pass in `tree.depth`.
    void update(Node current, Rectangle box, uint depth)
    in (current !is null, "Current node must not be null")
    do {

        import std.algorithm : either;

        auto currentFocusable = cast(FluidFocusable) current;

        // Count focus priority
        {

            // Get depth difference since last time
            const int depthDiff = depth - this.depth;

            // Count steps in change of depth
            priority += priorityDirection * abs(depthDiff);

            // Update depth
            this.depth = depth;

        }

        // Stop if the current node can't take focus
        if (!currentFocusable) return;

        // And it DOES have focus
        if (current.tree.focus is currentFocusable) {

            // Mark the node preceding it to the last encountered focusable node
            previous = last;

            // Clear the next node, so it can be overwritten by a correct value.
            next = null;

            // Reverse priority target
            priorityDirection = -1;

        }

        else {

            // Update positional focus
            updatePositional(currentFocusable, box);

            // There's no node to take focus next, set it now
            if (next is null) next = currentFocusable;

        }


        // Set the current node as the first focusable, if true
        if (first is null) first = currentFocusable;

        // Replace the last
        last = currentFocusable;

    }

    /// Check the given node's position and update `positional` to match.
    private void updatePositional(FluidFocusable node, Rectangle box) {

        // Note: This might give false-positives if the focused node has changed during this frame

        // Check each direction
        foreach (i, ref otherNode; positional) {

            const side = cast(Style.Side) i;
            const dist = distance2(box, side);

            // If a node took this spot before
            if (otherNode !is null) {

                // Ignore if the other node has higher priority
                if (otherNode.priority > priority) continue;

                // If priorities are equal, check if we're closer than the other node
                if (otherNode.priority == priority
                    && otherNode.distance2 < dist) continue;

            }

            // Check if this node matches the direction
            if (checkDirection(box, side)) {

                // Replace the node
                otherNode = WithPriority(priority, dist, node);

            }

        }

    }

    /// Check if the given box is located to the given side of the focus box.
    bool checkDirection(Rectangle box, Style.Side side) {

        // Distance between box sides facing each other.
        //
        // ↓ lastFocusBox  ↓ box
        // +======+        +------+
        // |      |        |      |
        // |      | ~~~~~~ |      |
        // |      |        |      |
        // +======+        +------+
        //   side ↑        ↑ side.reverse
        const distanceExternal = lastFocusBox.getSide(side) - box.getSide(side.reverse);

        // Distance between corresponding box sides.
        //
        // ↓ lastFocusBox  ↓ box
        // +======+        +------+
        // |      |        :      |
        // |      | ~~~~~~~~~~~~~ |
        // |      |        :      |
        // +======+        +------+
        //   side ↑          side ↑
        const distanceInternal = lastFocusBox.getSide(side) - box.getSide(side);

        // The condition for the return value to be true, is for distanceInternal to be greater than distanceExternal.
        // This is not the case in the opposite situation.
        //
        // For example, if we're checking if the box is on the *right* of lastFocusBox:
        //
        // trueish scenario:                                 falseish scenario:
        // Box is to the right of lastFocusBox               Box is the left of lastFocusBox
        //
        // ↓ lastFocusBox  ↓ box                             ↓ box           ↓ lastFocusBox
        // +======+        +------+                          +------+        +======+
        // |      | ~~~~~~ :      | external                 | ~~~~~~~~~~~~~~~~~~~~ | external
        // |      |        :      |    <                     |      :        :      |    >
        // |      | ~~~~~~~~~~~~~ | internal                 |      : ~~~~~~~~~~~~~ | internal
        // +======+        +------+                          +------+        +======+
        //   side ↑        ↑ side.reverse                      side ↑          side ↑
        const condition = abs(distanceInternal) > abs(distanceExternal);

        // ↓ box                    There is an edgecase though. If one box entirely overlaps the other on one axis, we
        // +--------------------+   might end up with unwanted behavior, for example, in a ScrollFrame, focus might
        // |   ↓ lastFocusBox   |   switch to the scrollbar instead of a child, as we would normally expect.
        // |   +============+   |
        // |   |            |   |   For this reason, we require both `distanceInternal` and `distanceExternal` to have
        // +---|            |---+   the same sign, as it normally would, but not here.
        //     |            |
        //     +============+       One can still navigate to the `box` using controls for the other axis.
        return condition
            && distanceInternal * distanceExternal >= 0;

    }

    /// Get the square of the distance between given box and `lastFocusBox`.
    float distance2(Rectangle box, Style.Side side) {

        /// Get the center of given rectangle on the axis opposite to the results of getSide.
        float center(Rectangle rect) {

            return side == Style.Side.left || side == Style.Side.right
                ? rect.y + rect.height
                : rect.x + rect.width;

        }

        // Distance between box sides facing each other, see `checkDirection`
        const distanceExternal = lastFocusBox.getSide(side) - box.getSide(side.reverse);

        /// Distance between centers of the boxes on the other axis
        const distanceOpposite = center(box) - center(lastFocusBox);

        return distanceExternal^^2 + distanceOpposite^^2;

    }

}

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

