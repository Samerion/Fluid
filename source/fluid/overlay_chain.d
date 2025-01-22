/// Implementation of `OverlayIO` using its own space to lay out its children.
module fluid.overlay_chain;

import std.array;
import std.algorithm;

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
        foreach (child; children) {

            const size = child.node.minSize;

            // Calculate the node's position based on the anchor
            const anchor = child.overlayable.anchor(inner);
            const layout = child.node.layout.nodeAlign[]
                .map!alignLayout
                .staticArray!2;
            const anchorPoint = anchor.end
                - Vector2(layout[0] * anchor.size.x, layout[1] * anchor.size.y)
                - Vector2(layout[0] * size.x,        layout[1] * size.y);

            import std.stdio;
            import std.stdio;
            debug writeln(i"$(anchor.end) - $(Vector2(layout[0] * anchor.size.x, layout[1] * anchor.size.y)) - $(Vector2(layout[0] * size.x,        layout[1] * size.y))");
            debug writeln(anchorPoint);

            drawChild(child.node, Rectangle(
                anchorPoint.tupleof,
                size.tupleof,
            ));

        }
    }

    private static alignLayout(NodeAlign alignment) {

        // TODO fill
        return alignment.predSwitch(
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
