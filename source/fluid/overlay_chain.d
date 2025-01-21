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
        foreach (child; children) {

            // Get the anchor
            const anchor = child.overlayable.anchor(inner);

            const anchorPoint = anchor.end;
            const size = child.node.minSize;

            drawChild(child.node, Rectangle(
                anchorPoint.tupleof,
                size.tupleof,
            ));

        }
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
