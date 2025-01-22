/// Implementation of `OverlayIO` using its own space to lay out its children.
module fluid.overlay_chain;

import fluid.node;
import fluid.utils;
import fluid.types;
import fluid.children;
import fluid.node_chain;

import fluid.io.overlay;

@safe:

/// The usual node builder for `OverlayChain`.
alias overlayChain = nodeBuilder!OverlayChain;

/// This node implements the `OverlayIO` interface by using its own space to lay out its children.
///
/// As this node is based on `NodeChain`, it accepts a single regular node to draw inside. It will always be drawn
/// first, before the overlay nodes. The usual, "regular" content can thus be placed as a regular child, and overlays
/// can then be spawned and be drawn above.
///
/// The `OverlayChain` can be considered a more modern alternative to `MapFrame`, however it is not guaranteed
/// to be compatible with the old backend. For future code, `OverlayChain` should generally be preferred, but it has
/// some drawbacks:
///
/// * Overlay nodes drawn on `OverlayChain` must implement `Overlayable`.
/// * `OverlayChain` is not a `Frame`, and cannot be used as one.
/// * It is not stylable; background color, border or decorations cannot be used, and margins may not work.
/// * Overlays are not considered in the chain's `minSize`.
/// * Position is relative to the window, not to the node.
class OverlayChain : NodeChain, OverlayIO {

    protected struct Child {
        Node node;
        Overlayable overlayable;
        Overlayable parent;
    }

    protected {

        /// Overlay nodes of the chain.
        Child[] children;

    }

    this(Node next = null) {
        super(next);
    }

    override void beforeResize(Vector2) {
        this.controlIO().startAndRelease();
    }

    override void afterResize(Vector2 space) {
        foreach (child; children) {
            resizeChild(child.node, space);
        }
    }

    override void afterDraw(Rectangle, Rectangle inner) {
        size_t newIndex;
        foreach (child; children) {

            // Filter removed nodes out
            if (child.node.toRemove) {
                child.node.toRemove = false;
                continue;
            }
            scope (exit) children[newIndex++] = child;

            const size = child.node.minSize;
            const nodeAlign = child.node.layout.nodeAlign;

            // Calculate the node's position based on the anchor
            const anchor = child.overlayable.anchor(inner);
            const layout = Vector2(
                alignLayout!'x'(nodeAlign[0], inner, anchor, size),
                alignLayout!'y'(nodeAlign[1], inner, anchor, size),
            );
            const anchorPoint = anchor.end
                - Vector2(layout.x * anchor.size.x, layout.y * anchor.size.y)
                - Vector2(layout.x * size.x,        layout.y * size.y);

            drawChild(child.node, Rectangle(
                anchorPoint.tupleof,
                size.tupleof,
            ));

        }
        children.length = newIndex;
    }

    private static alignLayout(char axis)(NodeAlign alignment, Rectangle inner, Rectangle anchor, Vector2 size) {

        import std.algorithm : predSwitch;

        if (alignment == NodeAlign.fill) {

            // +---- inner ---+
            // | . .|  <- end |
            // |. . |   space |
            // +----+====+    |
            // |    | . .|    |
            // |    |. . | <- anchor
            // |    +====+----+
            // | start   | . .|
            // | space-> |. . |
            // +---------+----+

            const startSpace = inner.end - anchor.end;
            const endSpace   = anchor.start - inner.start;

            static if (axis == 'x') {
                if (size.x <= startSpace.x) return 0;
                if (size.x <= endSpace.x)   return 1;
                return 0.5;
            }

            static if (axis == 'y') {
                if (size.y <= startSpace.y) return 0;
                if (size.y <= endSpace.y)   return 1;
                return 0.5;
            }

        }

        else return alignment.predSwitch(
            NodeAlign.start,  0,
            NodeAlign.center, 0.5,
            NodeAlign.end,    1,
        );

    }

    override void addOverlay(Overlayable overlayable, OverlayType[] type...) nothrow {

        auto node = cast(Node) overlayable;
        assert(node, "Given overlay is not a Node");

        children ~= Child(node, overlayable);
        updateSize();

        // Technically, updateSize could be avoided by resizing nothing but the newly added overlay,
        // and storing the relevant I/O systems. Right now, I find this approach easier.

    }

    override void addChildOverlay(Overlayable parent, Overlayable overlayable, OverlayType[] type...) nothrow {

        auto node = cast(Node) overlayable;
        assert(node, "Given overlay is not a Node");

        children ~= Child(node, overlayable, parent);
        updateSize();

    }

}
