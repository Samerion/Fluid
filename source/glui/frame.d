module glui.frame;

import raylib;

import glui.node;

/// This is a frame, basic container for other nodes.
class GluiFrame : GluiNode {

    /// Children of this frame.
    GluiNode[] children;

    /// Defines in what directions children of this frame should be placed.
    Direction direction;

    /// Denominator for content sizing
    private uint denominator;

    enum Direction {
        vertical,
        horizontal
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

        // Reset min size
        minSize = Vector2(0, 0);

        // Ignore the rest if there's no children
        if (!children.length) return;

        denominator = children
            .map!`a.layout.expand`
            .fold!`a + b`;

        // Vertical
        foreach (child; children) {

            child.resize(childSpace(child, available));
            minSize = childPosition(child, minSize);

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
            if (direction == Direction.vertical) position.y += size.y;
            else position.x += size.x;

        }

    }

    /// Params:
    ///     child     = Child to calculate.
    ///     previous  = Previous position.
    private Vector2 childPosition(GluiNode child, Vector2 previous) {

        import std.algorithm : max;

        // Vertical
        if (direction == Direction.vertical) {

            return Vector2(
                max(minSize.x, child.minSize.x),
                previous.y + child.minSize.y,
            );

        }

        // Horizontal
        else return Vector2(
            previous.x + child.minSize.x,
            max(minSize.y, child.minSize.y),
        );

    }

    import std.stdio;

    /// Get space for a child.
    /// Params:
    ///     child     = Child to place
    ///     available = Available space
    private Vector2 childSpace(GluiNode child, Vector2 available) {

        // Vertical
        if (direction == Direction.vertical) {

            return Vector2(
                available.x,
                child.layout.expand
                    ? available.y * child.layout.expand / denominator
                    : child.minSize.y,
            );

        }

        // Horizontal
        else return Vector2(
            child.layout.expand
                ? available.x * child.layout.expand / denominator
                : child.minSize.x,
            available.y,
        );

    }

}

/// Add children to a frame
T addChild(T : GluiFrame)(T parent, GluiNode[] nodes...) {

    parent ~= nodes;
    return parent;

}
