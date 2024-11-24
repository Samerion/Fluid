/// This module provides basic functionality for scrolling with a mouse wheel.
module fluid.io.scroll;

import fluid.node;

import fluid.tree.types;
import fluid.tree.action;

@safe:

/// An interface to be implemented by nodes that accept scroll input.
interface FluidScrollable {

    /// Returns true if the node can react to given scroll.
    ///
    /// Should return false if the given scroll has no effect, either because it scroll on an unsupported axis, or
    /// because the axis is currently maxed out.
    bool canScroll(Vector2 value) const;

    /// React to scroll wheel input.
    void scrollImpl(Vector2 value);

    /// Scroll to given child node.
    /// Params:
    ///     child     = Child to scroll to.
    ///     parentBox = Outer box of this node (the scrollable).
    ///     childBox  = Outer box of the child node (the target).
    /// Returns:
    ///     New rectangle for the childBox.
    Rectangle shallowScrollTo(const Node child, Rectangle parentBox, Rectangle childBox);

    /// Get current scroll value.
    float scroll() const;

    /// Set scroll value.
    float scroll(float value);

}

/// Scroll so the given node becomes visible.
/// Params:
///     node = Node to scroll to.
///     alignToTop = If true, the top of the element will be aligned to the top of the scrollable area.
ScrollIntoViewAction scrollIntoView(Node node, bool alignToTop = false) {

    auto action = new ScrollIntoViewAction;
    node.queueAction(action);
    action.alignToTop = alignToTop;

    return action;

}

/// Scroll so that the given node appears at the top, if possible.
ScrollIntoViewAction scrollToTop(Node node) {

    return scrollIntoView(node, true);

}

unittest {

    import fluid;
    import std.math;
    import std.array;
    import std.range;
    import std.algorithm;

    const viewportHeight = 10;

    auto io = new HeadlessBackend(Vector2(10, viewportHeight));
    auto root = vscrollFrame(
        layout!(1, "fill"),
        nullTheme,

        label("a"),
        label("b"),
        label("c"),
    );

    root.io = io;
    root.scrollBar.width = 0;  // TODO replace this with scrollBar.hide()

    // Prepare scrolling
    // Note: Changes made when scrolling will be visible during the next frame
    root.children[1].scrollIntoView;
    root.draw();

    auto getPositions() {
        return io.textures.map!(a => a.position).array;
    }

    // Find label positions
    auto positions = getPositions();

    // No theme so everything is as compact as it can be: the first label should be at the very top
    assert(positions[0].y.isClose(0));

    // It is reasonable to assume the text will be larger than 10 pixels (viewport height)
    // Other text will not render, since it's offscreen
    assert(positions.length == 1);

    io.nextFrame;
    root.draw();

    // TODO Because the label was hidden below the viewport, Fluid will align the bottom of the selected node with the
    // viewport which probably isn't appropriate in case *like this* where it should reveal the top of the node.
    auto texture1 = io.textures.front;
    assert(isClose(texture1.position.y + texture1.height, viewportHeight));
    assert(isClose(root.scroll, (root.scrollMax + 10) * 2/3 - 10));

    io.nextFrame;
    root.draw();

    auto scrolledPositions = getPositions();

    // TODO more tests. Scrolling while already in the viewport, scrolling while partially out of the view, etc.

}

class ScrollIntoViewAction : TreeAction {

    public {

        /// If true, try to display the child at the top.
        bool alignToTop;

    }

    private {

        /// The node this action attempts to put into view.
        Node target;

        Vector2 viewport;
        Rectangle childBox;

    }

    void reset(bool alignToTop = false) {

        this.toStop = false;
        this.alignToTop = alignToTop;

    }

    override void afterDraw(Node node, Rectangle, Rectangle paddingBox, Rectangle contentBox) {

        // Target node was drawn
        if (node is startNode) {

            // Make sure the action reaches the end of the tree
            target = node;
            startNode = null;

            // Get viewport size
            viewport = node.tree.io.windowSize;

            // Get the node's padding box
            childBox = node.focusBoxImpl(contentBox);


        }

        // Ignore children of the target node
        // Note: startNode is set until reached
        else if (startNode !is null) return;

        // Reached a scroll node
        // TODO What if the container isn't an ancestor
        else if (auto scrollable = cast(FluidScrollable) node) {

            // Perform the scroll
            childBox = scrollable.shallowScrollTo(target, paddingBox, childBox);

            // Aligning to top, make sure the child aligns with the parent
            if (alignToTop && childBox.y > paddingBox.y) {

                const offset = childBox.y - paddingBox.y;

                scrollable.scroll = scrollable.scroll + cast(size_t) offset;

            }

        }

    }

}
