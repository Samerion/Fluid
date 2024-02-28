///
module fluid.switch_slot;

import fluid.node;
import fluid.utils;
import fluid.style;
import fluid.backend;


@safe:


/// A switch slot will try each of its children and pick the first one that fits the available space. If the a node
/// is too large to fit, it will try the next one in the list until it finds one that matches, or the last node in the
/// list.
///
/// `null` is an acceptable value, indicating that no node should be drawn.
alias switchSlot = simpleConstructor!SwitchSlot;

/// ditto
class SwitchSlot : Node {

    public {

        Node[] availableNodes;
        Node node;

        /// If present, this node will only be drawn in case its principal node is hidden. In case the principal node is
        /// another `SwitchSlot`, this might be because it failed to match any non-null node.
        Node principalNode;

    }

    @property {

        alias isHidden = typeof(super).isHidden;

        override bool isHidden() const return {

            // Tree is available and resized
            if (tree && !tree.resizePending) {

                // Principal node is visible, hide self
                if (principalNode && !principalNode.isHidden)
                    return true;

                // Hide if no node was chosen
                return super.isHidden || node is null;

            }

            return super.isHidden;

        }

    }

    this(Node[] nodes...) {

        this.availableNodes ~= nodes;

    }

    /// Create a new slot that will only draw if this slot is hidden or ends up with a `null` node.
    SwitchSlot retry(Args...)(Args args) {

        auto slot = switchSlot(args);
        slot.principalNode = this;
        return slot;

    }

    override void resizeImpl(Vector2 availbleSpace) {

        minSize = Vector2();
        this.node = null;

        // Try each option
        foreach (node; availableNodes) {

            this.node = node;

            // Null node reached, stop with no minSize
            if (node is null) return;

            node.resize(tree, theme, availbleSpace);

            // Check if it fits within available space
            if (node.minSize.x > availbleSpace.x) continue;
            if (node.minSize.y > availbleSpace.y) continue;

            // Found a match, stop
            break;

        }

        // Copy minSize
        minSize = node.minSize;

    }

    override void drawImpl(Rectangle outer, Rectangle inner) {

        // No node to draw, stop
        if (node is null) return;

        // Draw the node
        node.draw(inner);

    }

    override bool hoveredImpl(Rectangle, Vector2) {

        return false;

    }

}

unittest {

    import fluid.frame;

    Frame bigFrame, smallFrame;
    int bigDrawn, smallDrawn;

    auto io = new HeadlessBackend;
    auto slot = switchSlot(
        bigFrame = new class Frame {
            override void resizeImpl(Vector2) {
                minSize = Vector2(300, 300);
            }
            override void drawImpl(Rectangle outer, Rectangle) {
                io.drawRectangle(outer, color!"f00");
                bigDrawn++;
            }
        },
        smallFrame = new class Frame {
            override void resizeImpl(Vector2) {
                minSize = Vector2(100, 100);
            }
            override void drawImpl(Rectangle outer, Rectangle) {
                io.drawRectangle(outer, color!"0f0");
                smallDrawn++;
            }
        },
    );

    slot.io = io;

    // By default, there should be enough space to draw the big frame
    slot.draw();

    assert(slot.node is bigFrame);
    assert(bigDrawn == 1);
    assert(smallDrawn == 0);

    // Reduce the viewport, this time the small frame should be drawn
    io.nextFrame;
    io.windowSize = Vector2(200, 200);
    slot.draw();

    assert(slot.node is smallFrame);
    assert(bigDrawn == 1);
    assert(smallDrawn == 1);

    // Do it again, but make it so neither fit
    io.nextFrame;
    io.windowSize = Vector2(50, 50);
    slot.draw();

    // The small one should be drawn regardless
    assert(slot.node is smallFrame);
    assert(bigDrawn == 1);
    assert(smallDrawn == 2);

    // Unless a null node is added
    io.nextFrame;
    slot.availableNodes ~= null;
    slot.updateSize();
    slot.draw();

    assert(slot.node is null);
    assert(bigDrawn == 1);
    assert(smallDrawn == 2);

    // Resize to fit the big node
    io.nextFrame;
    io.windowSize = Vector2(400, 400);
    slot.draw();

    assert(slot.node is bigFrame);
    assert(bigDrawn == 2);
    assert(smallDrawn == 2);

}

unittest {

    import fluid.frame;
    import fluid.structs;

    int principalDrawn, deputyDrawn;

    auto io = new HeadlessBackend;
    auto principal = switchSlot(
        layout!(1, "fill"),
        new class Frame {
            override void resizeImpl(Vector2) {
                minSize = Vector2(200, 200);
            }
            override void drawImpl(Rectangle outer, Rectangle) {
                io.drawRectangle(outer, color!"f00");
                principalDrawn++;
            }
        },
        null
    );
    auto deputy = principal.retry(
        layout!(1, "fill"),
        new class Frame {
            override void resizeImpl(Vector2 space) {
                minSize = Vector2(50, 200);
            }
            override void drawImpl(Rectangle outer, Rectangle) {
                io.drawRectangle(outer, color!"f00");
                deputyDrawn++;
            }
        }
    );
    auto root = vframe(
        layout!(1, "fill"),
        hframe(
            layout!(1, "fill"),
            deputy,
        ),
        hframe(
            layout!(1, "fill"),
            principal,
        ),
    );

    root.io = io;

    // At the default size, the principal should be preferred
    root.draw();

    assert(principalDrawn == 1);
    assert(deputyDrawn == 0);

    // Resize the window so that the principal can't fit
    io.nextFrame;
    io.windowSize = Vector2(300, 300);

    root.draw();

    assert(principalDrawn == 1);
    assert(deputyDrawn == 1);

}
