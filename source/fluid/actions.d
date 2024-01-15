/// Definitions for common tree actions; This is the Fluid tree equivalent to std.algorithm.
module fluid.actions;

import fluid.node;
import fluid.tree;
import fluid.input;
import fluid.backend;
import fluid.container;


@safe:


/// Set focus on the given node, if focusable, or the first of its focusable children. This will be done lazily during
/// the next draw. If calling `focusRecurseChildren`, the subject of the call will be excluded from taking focus.
/// Params:
///     parent = Container node to search in.
void focusRecurse(Node parent) {

    // Perform a tree action to find the child
    parent.queueAction(new FocusRecurseAction);

}

unittest {

    import fluid.space;
    import fluid.label;
    import fluid.button;

    auto io = new HeadlessBackend;
    auto root = vspace(
        label(""),
        button("", delegate { }),
        button("", delegate { }),
        button("", delegate { }),
    );

    // First paint: no node focused
    root.io = io;
    root.draw();

    assert(root.tree.focus is null, "No focus assigned on the first frame");

    io.nextFrame;

    // Recurse into the tree to focus on the first node
    root.focusRecurse();
    root.draw();

    assert(root.tree.focus.asNode is root.children[1], "First child is now focused");
    assert((cast(FluidFocusable) root.children[1]).isFocused);

}

/// ditto
void focusRecurseChildren(Node parent) {

    auto action = new FocusRecurseAction;
    action.excludeStartNode = true;

    parent.queueAction(action);

}

unittest {

    import fluid.space;
    import fluid.button;

    auto io = new HeadlessBackend;
    auto root = frameButton(
        button("", delegate { }),
        button("", delegate { }),
        delegate { }
    );

    root.io = io;

    // Typical focusRecurse call will focus the button
    root.focusRecurse;
    root.draw();

    assert(root.tree.focus is root);

    io.nextFrame;

    // If we want to make sure the action descends below the root, we must
    root.focusRecurseChildren;
    root.draw();

    assert(root.tree.focus.asNode is root.children[0]);

}

class FocusRecurseAction : TreeAction {

    public {

        bool excludeStartNode;

    }

    override void beforeDraw(Node node, Rectangle) {

        // Ignore if the branch is disabled
        if (node.isDisabledInherited) return;

        // Ignore the start node if excluded
        if (excludeStartNode && node is startNode) return;

        // Check if the node is focusable
        if (auto focusable = cast(FluidFocusable) node) {

            // Give it focus
            focusable.focus();

            // We're done here
            stop;

        }

    }

}

/// Scroll so the given node becomes visible.
/// Params:
///     node = Node to scroll to.
void scrollIntoView(Node node) {

    node.queueAction(new ScrollIntoViewAction);

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
        cast(Theme) null,

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

    auto getPositions() => io.textures.map!(a => a.position).array;

    // Find label positions
    auto positions = getPositions();

    // No theme so everything is as compact as it can be: the first label should be at the very top
    assert(positions[0].y.isClose(0));
    assert(positions[1].y > positions[0].y);
    assert(positions[2].y > positions[1].y);

    // It is reasonable to assume the text will be larger than 10 pixels (viewport height)
    assert(positions[1].y > viewportHeight);

    // TODO Because the label was hidden below the viewport, Fluid will align the bottom of the selected node with the
    // viewport which probably isn't appropriate in case *like this* where it should reveal the top of the node.
    auto texture1 = io.textures.dropOne.front;
    assert(root.scroll.isClose(texture1.position.y + texture1.height - viewportHeight));

    io.nextFrame;
    root.draw();

    auto scrolledPositions = getPositions();

    // Make sure all the labels are scrolled
    assert(equal!((a, b) => isClose(a.y - root.scroll, b.y))(positions, scrolledPositions));

    // TODO more tests. Scrolling while already in the viewport, scrolling while partially out of the view, etc.

}

class ScrollIntoViewAction : TreeAction {

    private {

        /// The node this action attempts to put into view.
        Node target;

        Vector2 viewport;
        Rectangle childBox;

    }

    override void afterDraw(Node node, Rectangle, Rectangle paddingBox, Rectangle) {

        // Target node was drawn
        if (node is startNode) {

            // Make sure the action reaches the end of the tree
            target = node;
            startNode = null;

            // Get viewport size
            viewport = node.tree.io.windowSize;

            // Get the node's padding box
            childBox = paddingBox;


        }

        // Ignore children of the target node
        // Note: startNode is set until reached
        else if (startNode !is null) return;

        // Reached a container node
        else if (auto container = cast(FluidContainer) node) {

            // Perform the scroll
            childBox = container.shallowScrollTo(node, viewport, paddingBox, childBox);

        }

    }

}
