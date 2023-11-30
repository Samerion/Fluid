///
module glui.space;

import raylib;

import std.math;
import std.range;
import std.string;
import std.traits;
import std.algorithm;

import glui.node;
import glui.style;
import glui.utils;
import glui.children;
import glui.container;


@safe:


/// Make a new vertical space.
alias vspace = simpleConstructor!GluiSpace;

/// Make a new horizontal space.
alias hspace = simpleConstructor!(GluiSpace, (a) {

    a.directionHorizontal = true;

});

/// This is a space, a basic container for other nodes.
///
/// Space only acts as a container and doesn't implement styles and doesn't take focus. It can be very useful to build
/// overlaying nodes, eg. with `GluiOnionFrame`.
class GluiSpace : GluiNode, GluiContainer {

    mixin DefineStyles;

    /// Children of this frame.
    Children children;

    /// Defines in what directions children of this frame should be placed.
    ///
    /// If true, children are placed horizontally, if false, vertically.
    bool horizontal;

    alias directionHorizontal = horizontal;

    private {

        /// Denominator for content sizing.
        uint denominator;

        /// Space reserved for shrinking elements.
        uint reservedSpace;

    }

    // Generate constructors
    static foreach (index; 0 .. BasicNodeParamLength) {

        this(BasicNodeParam!index params, GluiNode[] nodes...) {

            super(params);
            this.children ~= nodes;

        }

    }

    /// Add children.
    pragma(inline, true)
    void opOpAssign(string operator : "~", T)(T nodes) {

        children ~= nodes;

    }

    override Rectangle shallowScrollTo(const GluiNode, Vector2, Rectangle, Rectangle childBox) {

        // no-op, reordering should not be done without explicit orders
        return childBox;

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
        GluiNode[] expandChildren;
        foreach (child; children) {

            // This node expands and isn't hidden
            if (child.layout.expand && !child.isHidden) {

                // Make it happen later
                expandChildren ~= child;

                // Add to the denominator
                denominator += child.layout.expand;

            }

            // Check non-expand nodes now
            else {

                child.resize(tree, theme, childSpace(child, available));
                minSize = childPosition(child.minSize, minSize);

                // Reserve space for this node
                reservedSpace += directionHorizontal
                    ? cast(uint) child.minSize.x
                    : cast(uint) child.minSize.y;

            }

        }

        // Calculate the size of expanding children last
        foreach (child; expandChildren) {

            // Resize the child
            child.resize(tree, theme, childSpace(child, available));

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
        minSize = childPosition(expandSize, minSize);

    }

    protected override void drawImpl(Rectangle, Rectangle area) {

        assertClean(children, "Children were changed without calling updateSize().");

        auto position = Vector2(area.x, area.y);

        foreach (child; filterChildren) {

            // Get params
            const size = childSpace(child, Vector2(area.width, area.height));
            const rect = Rectangle(
                position.x, position.y,
                size.x, size.y
            );

            // Draw the child
            child.draw(rect);

            // Offset position
            if (directionHorizontal) position.x += cast(int) size.x;
            else position.y += cast(int) size.y;

        }

    }

    /// List children in the space, removing all nodes queued for deletion beforehand.
    protected auto filterChildren() {

        struct ChildIterator {

            GluiSpace node;

            int opApply(int delegate(GluiNode) @safe fun) @trusted {

                node.children.lock();
                scope (exit) node.children.unlock();

                size_t destinationIndex = 0;

                // Iterate through all children. When we come upon ones that are queued for deletion,
                foreach (sourceIndex, child; node.children) {

                    const toRemove = child.toRemove;
                    child.toRemove = false;

                    // Ignore children that are to be removed
                    if (toRemove) continue;

                    // Yield the child
                    const status = fun(child);

                    // Move the child if needed
                    if (sourceIndex != destinationIndex) {

                        node.children.forceMutable[destinationIndex] = child;

                    }

                    // Stop iteration if requested
                    else if (status) return status;

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

    /// Iterate over every child and perform the painting function. Will automatically remove nodes queued for removal.
    /// Returns: An iterator that goes over all nodes.
    deprecated("Use filterChildren instead")
    protected void drawChildren(void delegate(GluiNode) @safe painter) {

        GluiNode[] leftovers;

        children.lock();
        scope (exit) children.unlock();

        // Draw each child and get rid of removed children
        auto range = children[]

            // Check if the node is queued for removal
            .filter!((node) {
                const status = node.toRemove;
                node.toRemove = false;
                return !status;
            })

            // Draw the node
            .tee!((node) => painter(node));

        // Do what we ought to do
        () @trusted {

            // Process the children and move them back to the original array
            auto leftovers = range.moveAll(children.forceMutable);

            // Adjust the array size
            children.forceMutable.length -= leftovers.length;

        }();

    }

    protected override bool hoveredImpl(Rectangle, Vector2) const {

        return false;

    }

    protected override const(Style) pickStyle() const {

        return null;

    }

    /// Params:
    ///     child     = Child size to add.
    ///     previous  = Previous position.
    private Vector2 childPosition(Vector2 child, Vector2 previous) const {

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

    /// Get space for a child.
    /// Params:
    ///     child     = Child to place
    ///     available = Available space
    private Vector2 childSpace(const GluiNode child, Vector2 available) const
    in(
        child.isHidden || child.layout.expand <= denominator,
        format!"Nodes %s/%s sizes are out of date, call updateSize after updating the tree or layout (%s/%s)"(
            typeid(this), typeid(child), child.layout.expand, denominator,
        )
    )
    out(
        r; [r.tupleof].all!isFinite,
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

            return Vector2(
                child.layout.expand
                    ? avail * child.layout.expand / denominator
                    : child.minSize.x,
                available.y,
            );

        }

        // Vertical
        else {

            const avail = (available.y - reservedSpace);

            return Vector2(
                available.x,
                child.layout.expand
                    ? avail * child.layout.expand / denominator
                    : child.minSize.y,
            );

        }

    }

}
