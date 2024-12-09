///
module fluid.space;

import std.math;
import std.range;
import std.string;
import std.traits;
import std.algorithm;

import fluid.node;
import fluid.style;
import fluid.utils;
import fluid.backend;
import fluid.children;


@safe:


/// This is a space, a basic container for other nodes.
///
/// Nodes are laid in a column (`vframe`) or in a row (`hframe`).
///
/// Space only acts as a container and doesn't implement styles and doesn't take focus. It's very useful as a helper for
/// building layout, while `Frame` remains to provide styling.
alias vspace = simpleConstructor!Space;

/// ditto
alias hspace = simpleConstructor!(Space, (a) {

    a.directionHorizontal = true;

});

/// ditto
class Space : Node {

    public {

        /// Children of this frame.
        Children children;

        /// Defines in what directions children of this frame should be placed.
        ///
        /// If true, children are placed horizontally, if false, vertically.
        bool isHorizontal;

        alias horizontal = isHorizontal;
        alias directionHorizontal = horizontal;

    }

    private {

        /// Denominator for content sizing.
        uint denominator;

        /// Space reserved for shrinking elements.
        float reservedSpace;

    }

    /// Create the space and fill it with given nodes.
    this(Node[] nodes...) {

        this.children ~= nodes;

    }

    /// Create the space using nodes from the given range.
    this(Range)(Range range)
    if (isInputRange!Range)
    do {

        this.children ~= range;

    }

    /// Add children.
    pragma(inline, true)
    void opOpAssign(string operator : "~", T)(T nodes) {

        children ~= nodes;

    }

    protected override void resizeImpl(Vector2 available) {

        import std.algorithm : max, map, fold;

        // Now that we're recalculating the layout, we can remove the dirty flag from children
        children.clearDirty;

        // Reset size
        minSize = Vector2(0, 0);
        reservedSpace = 0;
        denominator = 0;

        // Ignore the rest if there's no children
        if (!children.length) return;

        Vector2 maxExpandSize;

        // Collect expanding children in a separate array
        Node[] expandChildren;
        size_t visibleChildren;
        foreach (child; children) {

            visibleChildren += !child.isHidden;

            // This node expands and isn't hidden
            if (child.layout.expand && !child.isHidden) {

                // Make it happen later
                expandChildren ~= child;

                // Add to the denominator
                denominator += child.layout.expand;

            }

            // Check non-expand nodes now
            else {

                resizeChild(child, childSpace(child, available, false));
                minSize = addSize(child.minSize, minSize);

                // Reserve space for this node
                reservedSpace += directionHorizontal
                    ? child.minSize.x
                    : child.minSize.y;

            }

        }

        const gapSpace 
            = visibleChildren == 0 ? 0
            : isHorizontal ? style.gap.sideX * (visibleChildren - 1u)
            :                style.gap.sideY * (visibleChildren - 1u);

        // Reserve space for gaps
        reservedSpace += gapSpace;

        if (isHorizontal)
            minSize.x += gapSpace;
        else
            minSize.y += gapSpace;

        // Calculate the size of expanding children last
        foreach (child; expandChildren) {

            // Resize the child
            resizeChild(child, childSpace(child, available, false));

            const childSize = child.minSize;
            const childExpand = child.layout.expand;

            const segmentSize = horizontal
                ? Vector2(childSize.x / childExpand, childSize.y)
                : Vector2(childSize.x, childSize.y / childExpand);

            // Reserve expand space
            maxExpandSize.x = max(maxExpandSize.x, segmentSize.x);
            maxExpandSize.y = max(maxExpandSize.y, segmentSize.y);

        }

        const expandSize = horizontal
            ? Vector2(maxExpandSize.x * denominator, maxExpandSize.y)
            : Vector2(maxExpandSize.x, maxExpandSize.y * denominator);

        // Add the expand space
        minSize = addSize(expandSize, minSize);

    }

    protected override void drawImpl(Rectangle, Rectangle area) {

        assertClean(children, "Children were changed without calling updateSize().");

        auto position = start(area);

        foreach (child; filterChildren) {

            // Ignore if this child is not visible
            if (child.isHidden) continue;

            // Get params
            const size = childSpace(child, size(area), true);
            const rect = Rectangle(
                position.x, position.y,
                size.x, size.y
            );

            // Draw the child
            drawChild(child, rect);

            // Offset position
            position = childOffset(position, size);

        }

    }

    /// List children in the space, removing all nodes queued for deletion beforehand.
    protected auto filterChildren() {

        struct ChildIterator {

            Space node;

            int opApply(int delegate(Node) @safe fun) @trusted {

                foreach (_, node; this) {

                    if (auto result = fun(node)) {
                        return result;
                    }

                }
                return 0;

            }

            int opApply(int delegate(size_t index, Node) @safe fun) @trusted {

                node.children.lock();
                scope (exit) node.children.unlock();

                size_t destinationIndex = 0;
                int end = 0;

                // Iterate through all children. When we come upon ones that are queued for deletion,
                foreach (sourceIndex, child; node.children) {

                    const toRemove = child.toRemove;
                    child.toRemove = false;

                    // Ignore children that are to be removed
                    if (toRemove) continue;

                    // Yield the child
                    if (!end)
                        end = fun(destinationIndex, child);

                    // Move the child if needed
                    if (sourceIndex != destinationIndex) {

                        node.children.forceMutable[destinationIndex] = child;

                    }

                    // Stop iteration if requested — and if there's nothing to move
                    else if (end) return end;

                    // Set space for next nodes
                    destinationIndex++;


                }

                // Adjust length
                node.children.forceMutable.length = destinationIndex;

                return 0;

            }

        }

        return ChildIterator(this);

    }

    /// Space does not take hover; isHovered is always false.
    protected override bool hoveredImpl(Rectangle, Vector2) {

        return false;

    }

    /// Params:
    ///     child     = Child size to add.
    ///     previous  = Previous position.
    private Vector2 addSize(Vector2 child, Vector2 previous) const {

        import std.algorithm : max;

        // Horizontal
        if (directionHorizontal) {

            return Vector2(
                previous.x + child.x,
                max(minSize.y, child.y),
            );

        }

        // Vertical
        else return Vector2(
            max(minSize.x, child.x),
            previous.y + child.y,
        );

    }

    /// Calculate the offset for the next node, given the `childSpace` result for its previous sibling.
    protected Vector2 childOffset(Vector2 currentOffset, Vector2 childSpace) {

        if (isHorizontal)
            return currentOffset + Vector2(childSpace.x + style.gap.sideX, 0);
        else
            return currentOffset + Vector2(0, childSpace.y + style.gap.sideY);

    }

    /// Get space for a child.
    /// Params:
    ///     child     = Child to place
    ///     available = Available space
    protected Vector2 childSpace(const Node child, Vector2 available, bool stateful = true) const
    in(
        child.isHidden || child.layout.expand <= denominator,
        format!"Nodes %s/%s sizes are out of date, call updateSize after updating the tree or layout (%s/%s)"(
            typeid(this), typeid(child), child.layout.expand, denominator,
        )
    )
    out(
        r; only(r.tupleof).all!isFinite,
        format!"space: child %s given invalid size %s. available = %s, expand = %s, denominator = %s, reserved = %s"(
            typeid(child), r, available, child.layout.expand, denominator, reservedSpace
        )
    )
    do {

        // Hidden, give it no space
        if (child.isHidden) return Vector2();

        // Horizontal
        if (directionHorizontal) {

            const avail = (available.x - reservedSpace);
            const minSize = stateful
                ? child.minSize.x
                : available.x;

            return Vector2(
                child.layout.expand
                    ? avail * child.layout.expand / denominator
                    : minSize,
                available.y,
            );

        }

        // Vertical
        else {

            const avail = (available.y - reservedSpace);
            const minSize = stateful
                ? child.minSize.y
                : available.y;

            return Vector2(
                available.x,
                child.layout.expand
                    ? avail * child.layout.expand / denominator
                    : minSize,
            );

        }

    }

}

///
unittest {

    import fluid;

    // A vspace will align all its content in a column
    vspace(
        label("First entry"),
        label("Second entry"),
        label("Third entry"),
    );

    // hspace will lay out the nodes in a row
    hspace(
        label("One, "),
        label("Two, "),
        label("Three!"),
    );

    // Combine them to quickly build layouts!
    vspace(
        label("Are you sure you want to proceed?"),
        hspace(
            button("Yes", delegate { }),
            button("Cancel", delegate { }),
        ),
    );

}
