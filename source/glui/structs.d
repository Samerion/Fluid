///
module glui.structs;

import raylib;
import std.conv;

import glui.node;
import glui.input;
import glui.style;


@safe:


// Disable scissors mode on macOS in Raylib 3, it's broken; see #60
version (Glui_Raylib3) version (OSX) version = Glui_DisableScissors;

/// Create a new layout
/// Params:
///     expand = Numerator of the fraction of space this node should occupy in the parent.
///     align_ = Align of the node (horizontal and vertical).
///     alignX = Horizontal align of the node.
///     alignY = Vertical align of the node.
Layout layout(uint expand, NodeAlign alignX, NodeAlign alignY) {

    return Layout(expand, [alignX, alignY]);

}

/// Ditto
Layout layout(uint expand, NodeAlign align_) {

    return Layout(expand, align_);

}

/// Ditto
Layout layout(NodeAlign alignX, NodeAlign alignY) {

    return Layout(0, [alignX, alignY]);

}

/// Ditto
Layout layout(NodeAlign align_) {

    return Layout(0, align_);

}

/// Ditto
Layout layout(uint expand) {

    return Layout(expand);

}

/// CTFE version of the layout constructor, allows using strings instead of enum members, to avoid boilerplate.
Layout layout(uint expand, string alignX, string alignY)() {

    enum valueX = alignX.to!NodeAlign;
    enum valueY = alignY.to!NodeAlign;

    return Layout(expand, [valueX, valueY]);

}

/// Ditto
Layout layout(uint expand, string align_)() {

    enum valueXY = align_.to!NodeAlign;

    return Layout(expand, valueXY);

}

/// Ditto
Layout layout(string alignX, string alignY)() {

    enum valueX = alignX.to!NodeAlign;
    enum valueY = alignY.to!NodeAlign;

    return Layout(0, [valueX, valueY]);

}

/// Ditto
Layout layout(string align_)() {

    enum valueXY = align_.to!NodeAlign;

    return Layout(0, valueXY);

}

/// Ditto
Layout layout(uint expand)() {

    return Layout(expand);

}

unittest {

    assert(layout!1 == layout(1));
    assert(layout!("fill") == layout(NodeAlign.fill, NodeAlign.fill));
    assert(layout!("fill", "fill") == layout(NodeAlign.fill));

    assert(!__traits(compiles, layout!"expand"));
    assert(!__traits(compiles, layout!("expand", "noexpand")));
    assert(!__traits(compiles, layout!(1, "whatever")));
    assert(!__traits(compiles, layout!(2, "foo", "bar")));

}

/// Represents a node's layout
struct Layout {

    /// Fraction of available space this node should occupy in the node direction.
    ///
    /// If set to `0`, the node doesn't have a strict size limit and has size based on content.
    uint expand;

    /// Align the content box to a side of the occupied space.
    NodeAlign[2] nodeAlign;

    string toString() const {

        import std.format;

        const equalAlign = nodeAlign[0] == nodeAlign[1];
        const startAlign = equalAlign && nodeAlign[0] == NodeAlign.start;

        if (expand) {

            if (startAlign) return format!".layout!%s"(expand);
            else if (equalAlign) return format!".layout!(%s, %s)"(expand, nodeAlign[0]);
            else return format!".layout!(%s, %s, %s)"(expand, nodeAlign[0], nodeAlign[1]);

        }

        else {

            if (startAlign) return format!"Layout()";
            else if (equalAlign) return format!".layout!%s"(nodeAlign[0]);
            else return format!".layout!(%s, %s)"(nodeAlign[0], nodeAlign[1]);

        }

    }

}

enum NodeAlign {

    start, center, end, fill

}

///
struct FocusDirection {

    struct WithDistance {

        int steps;
        GluiFocusable node;

    }

    /// Available space box of the focused item after last frame.
    Rectangle lastFocusBox;

    /// Nodes that may get focus with tab navigation.
    GluiFocusable previous, next;

    /// First and last focusable nodes in the tree.
    GluiFocusable first, last;

    /// Focusable nodes, by direction from the focused node. Nodes are chosen by tree distance.
    WithDistance[4] positional;

    /// Iteration steps made towards the focused node.
    ///
    /// Increased until the focused node is found, decremented afterwards. As a result, values will be the highest for
    /// nodes near the focused one.
    int steps;

    private {

        /// Value `steps` is summed with on each step. `1` before finding the focused node, `-1` after.
        int stepsDirection = 1;

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
    ///     box     = Available space box of the node. This is the argument passed to the child in `draw(Rectangle)`
    ///     depth   = Current tree depth. Pass in `tree.depth`.
    void update(GluiNode current, Rectangle box, uint depth)
    in (current !is null, "Current node must not be null")
    do {

        import std.math : abs;
        import std.algorithm : either;

        auto currentFocusable = cast(GluiFocusable) current;

        // Count steps
        {

            // Get depth difference since last time
            const int depthDiff = depth - this.depth;

            // Count number of steps made
            const stepsMade = 0 + abs(depthDiff);

            // Count leaf steps
            steps += stepsDirection * stepsMade;

            // Update depth
            this.depth = depth;

        }

        // Stop if the current node can't take focus
        if (!currentFocusable) return;

        debug (Glui_FocusOrderPriority)
        () @trusted {

            import std.string;
            DrawText(format!"%s"(steps).toStringz, cast(int)box.x, cast(int)box.y, 5, Colors.BLACK);

        }();

        // And it DOES have focus
        if (currentFocusable.isFocused) {

            // Mark the node preceding it to the last encountered focusable node
            previous = last;

            // Clear the next node, so it can be overwritten by a correct value.
            next = null;

            // Reverse step direction
            stepsDirection = -1;

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
    private void updatePositional(GluiFocusable node, Rectangle box) {

        // Check each direction
        foreach (i, ref otherNode; positional) {

            const side = cast(Style.Side) i;

            // Ignore the direction if another node was found closer to the focused node
            // Note: This might give false-positives if the focused node has changed during this frame
            if (otherNode.node !is null && otherNode.steps >= steps) continue;

            // Check this direction
            if (checkDirection(box, side)) {

                // Replace the node
                otherNode = WithDistance(steps, node);

            }

        }

    }

    /// Check if the given box is located to the given side of the focus box.
    bool checkDirection(Rectangle box, Style.Side side) {

        import std.math;

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
        // |      |        :      |                          |      :        :      |
        // |      | ~~~~~~~~~~~~~ | internal                 |      : ~~~~~~~~~~~~~ | internal
        // +======+        +------+                          +------+        +======+
        //   side ↑        ↑ side.reverse                      side ↑          side ↑
        const condition = abs(distanceInternal) > abs(distanceExternal);

        // ↓ box                    There is an edgecase though. If one box entirely overlaps the other on one axis, we
        // +--------------------+   might end up with unwanted behavior, for example, in a GluiScrollFrame, focus might
        // |   ↓ lastFocusBox   |   switch to the scrollbar instead of a child, as we would normally expect.
        // |   +============+   |
        // |   |            |   |   For this reason, we require both `distanceInternal` and `distanceExternal` to have
        // +---|            |---+   the same sign, as it normally would, but not here.
        //     |            |
        //     +============+       One can still navigate to the `box` using controls for the other axis.
        const sameSign = distanceInternal * distanceExternal >= 0;

        return sameSign && condition;

    }

}

/// Global data for the layout tree.
struct LayoutTree {

    /// Root node of the tree.
    GluiNode root;

    /// Top-most hovered node in the tree.
    GluiNode hover;

    /// Currently focused node.
    GluiFocusable focus;

    /// Focus direction data.
    FocusDirection focusDirection;

    /// Padding box of the currently focused node. Only available after the node has been drawn.
    ///
    /// See_also: `focusDirection.lastFocusBox`.
    Rectangle focusBox;

    /// Check if keyboard input was handled after rendering is has completed.
    bool keyboardHandled;

    /// Current node drawing depth.
    uint depth;

    package uint _disabledDepth;

    /// Current depth of "disabled" nodes, incremented for any node descended into, while any of the ancestors is
    /// disabled.
    deprecated("To be removed in 0.7.0. Use boolean `isBranchDisabled` instead. For iteration depth, check out `depth`")
    @property
    ref inout(uint) disabledDepth() inout { return _disabledDepth; }

    bool isBranchDisabled;

    /// Scissors stack.
    package Rectangle[] scissors;

    version (Glui_DisableScissors) {

        Rectangle intersectScissors(Rectangle rect) { return rect; }
        void pushScissors(Rectangle) { }
        void popScissors() { }

    }

    else {

        /// Intersect the given rectangle against current scissor area.
        Rectangle intersectScissors(Rectangle rect) {

            import std.algorithm : min, max;

            // No limit applied
            if (!scissors.length) return rect;

            const b = scissors[$-1];

            Rectangle result;

            // Intersect
            result.x = max(rect.x, b.x);
            result.y = max(rect.y, b.y);
            result.w = min(rect.x + rect.w, b.x + b.w) - result.x;
            result.h = min(rect.y + rect.h, b.y + b.h) - result.y;

            return result;

        }

        /// Start scissors mode.
        void pushScissors(Rectangle rect) {

            auto result = rect;

            // There's already something on the stack
            if (scissors.length) {

                // Intersect
                result = intersectScissors(rect);

            }

            // Push to the stack
            scissors ~= result;

            // Start the mode
            applyScissors(result);

        }

        void popScissors() @trusted {

            // Pop the stack
            scissors = scissors[0 .. $-1];

            // Pop the mode
            EndScissorMode();

            // There's still something left
            if (scissors.length) {

                // Start again
                applyScissors(scissors[$-1]);

            }

        }

        private void applyScissors(Rectangle rect) @trusted {

            import glui.utils;

            // End the current mode, if any
            if (scissors.length) EndScissorMode();

            version (Glui_Raylib3) const scale = hidpiScale;
            else                   const scale = Vector2(1, 1);

            // Start this one
            BeginScissorMode(
                to!int(rect.x * scale.x),
                to!int(rect.y * scale.y),
                to!int(rect.w * scale.x),
                to!int(rect.h * scale.y),
            );

        }

    }

}
