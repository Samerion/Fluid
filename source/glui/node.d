module glui.node;

import raylib;

import glui.style;
import glui.structs;

/// Represents a Glui node.
abstract class GluiNode {

    /// Layout for this node.
    Layout layout;

    /// Style of this node.
    Style style;

    /// Minimum size of the node.
    protected auto minSize = Vector2(0, 0);

    /// Params:
    ///     layout = Layout for this node.
    ///     style = Style of this node.
    this(Layout layout = Layout.init, Style style = null) {

        this.layout = layout;
        this.style  = style;

    }

    /// Ditto
    this(Style style = null, Layout layout = Layout.init) {

        this(layout, style);

    }

    /// Ditto
    this() {

        this(Layout.init, null);

    }

    /// Draw this node.
    final void draw() {

        assert(style, "Cannot draw a node lacking style.");

        const space = Vector2(GetScreenWidth, GetScreenHeight);

        resize(space);
        draw(Rectangle(0, 0, space.x, space.y));

    }

    /// Draw this node at specified location.
    final protected void draw(Rectangle space) const {

        const spaceV = Vector2(space.width, space.height);

        // Get parameters
        const size = Vector2(
            layout.nodeAlign[0] == NodeAlign.fill ? space.width  : minSize.x,
            layout.nodeAlign[1] == NodeAlign.fill ? space.height : minSize.y,
        );
        const position = position(space, size);

        // Draw the node
        drawImpl(
            Rectangle(
                position.x, position.y,
                size.x,     size.y,
            )
        );

    }

    /// Recalculate the minumum node size and update the `minSize` property.
    /// Params:
    ///     space = Available space.
    protected abstract void resize(Vector2 space);
    // TODO: only resize if the parent was resized.

    /// Draw this node.
    /// Params:
    ///     rect = Area the node should draw in.
    protected abstract void drawImpl(Rectangle rect) const;

    /// Get the node position.
    private Vector2 position(Rectangle space, Vector2 usedSpace) const {

        float positionImpl(NodeAlign align_, lazy float spaceLeft) {

            with (NodeAlign)
            final switch (align_) {

                case start, fill: return 0;
                case center: return spaceLeft / 2;
                case end: return spaceLeft;

            }

        }

        return Vector2(
            space.x + positionImpl(layout.nodeAlign[0], space.width  - usedSpace.x),
            space.y + positionImpl(layout.nodeAlign[1], space.height - usedSpace.y),
        );

    }

}
