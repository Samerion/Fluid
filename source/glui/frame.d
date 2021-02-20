module glui.frame;

import raylib;

import glui.node;

/// This is a frame, basic container for other nodes.
class GluiFrame : GluiNode {

    /// Children of this frame.
    GluiNode[] children;

    /// Defines in what directions children of this frame should be placed.
    ///
    /// If true, children are placed horizontally, if false, vertically.
    bool directionHorizontal;

    private {

        /// Denominator for content sizing.
        uint denominator;

        /// Space reserved for shrinking elements.
        uint reservedSpace;

    }

    /// Params:
    ///     children = Children to add.
    this(T...)(T sup) {

        super(sup);

    }

    /// Add children.
    pragma(inline, true)
    void opOpAssign(string operator : "~", T)(T nodes) {

        children ~= nodes;

    }

    protected override void resize(Vector2 available) {

        import std.algorithm : max, map, fold;

        // Reset size
        minSize = Vector2(0, 0);
        reservedSpace = 0;
        denominator = 0;

        // Ignore the rest if there's no children
        if (!children.length) return;

        // Construct a new node list
        GluiNode[] nodeList;
        foreach (child; children) {

            // This node expands
            if (child.layout.expand) {

                // Append
                nodeList ~= child;

                // Add to the denominator
                denominator += child.layout.expand;

            }

            // Prepend to ensure the child will be checked first
            else nodeList = child ~ nodeList;

        }

        // Vertical
        foreach (child; nodeList) {

            child.resize(childSpace(child, available));
            minSize = childPosition(child, minSize);

            // If this child doesn't expand
            if (child.layout.expand == 0) {

                // Reserve space for it
                reservedSpace += directionHorizontal
                    ? cast(uint) child.minSize.x
                    : cast(uint) child.minSize.y;

            }

        }

    }

    protected override void drawImpl(Rectangle area) {

        style.drawBackground(area);

        auto position = Vector2(area.x, area.y);

        foreach (child; children) {

            // Get params
            const size = childSpace(child, Vector2(area.width, area.height));
            const rect = Rectangle(
                position.x, position.y,
                size.x, size.y
            );

            // Draw the child
            child.draw(rect);

            // Offset position
            if (directionHorizontal) position.x += size.x;
            else position.y += size.y;

        }

    }

    /// Params:
    ///     child     = Child to calculate.
    ///     previous  = Previous position.
    private Vector2 childPosition(GluiNode child, Vector2 previous) {

        import std.algorithm : max;

        // Horizontal
        if (directionHorizontal) {

            return Vector2(
                previous.x + child.minSize.x,
                max(minSize.y, child.minSize.y),
            );

        }

        // Vertical
        else return Vector2(
            max(minSize.x, child.minSize.x),
            previous.y + child.minSize.y,
        );

    }

    import std.stdio;

    /// Get space for a child.
    /// Params:
    ///     child     = Child to place
    ///     available = Available space
    private Vector2 childSpace(GluiNode child, Vector2 available) {

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

/// Add children to a frame
T addChild(T : GluiFrame)(T parent, GluiNode[] nodes...) {

    parent ~= nodes;
    return parent;

}
