/// Definitions for common tree actions; This is the Fluid tree equivalent to std.algorithm.
module fluid.actions;

import fluid.node;
import fluid.tree;
import fluid.input;
import fluid.scroll;
import fluid.backend;

import fluid.io.focus;

import fluid.future.pipe;


@safe:


/// Abstract class for tree actions that find and return a node.
abstract class NodeSearchAction : TreeAction, Publisher!Node {

    public {

        /// Node this action has found.
        Node result;

    }

    private {

        /// Event that runs when the tree action finishes.
        Event!Node finished;

    }

    alias then = typeof(super).then;
    alias then = Publisher!Node.then;
    alias subscribe = typeof(super).subscribe;
    alias subscribe = Publisher!Node.subscribe;

    override void clearSubscribers() {
        super.clearSubscribers();
        finished.clearSubscribers();
    }

    override void subscribe(Subscriber!Node subscriber) {
        finished.subscribe(subscriber);
    }

    override void beforeTree(Node node, Rectangle rect) {
        super.beforeTree(node, rect);
        result = null;
    }

    override void stopped() {
        super.stopped();
        finished(result);
    }

}

abstract class FocusSearchAction : NodeSearchAction, Publisher!Focusable {

    private {

        /// Event that runs when the tree action finishes.
        Event!Focusable finished;

    }

    alias then = typeof(super).then;
    alias then = Publisher!Focusable.then;
    alias subscribe = typeof(super).subscribe;
    alias subscribe = Publisher!Focusable.subscribe;

    override void clearSubscribers() {
        super.clearSubscribers();
        finished.clearSubscribers();
    }

    override void subscribe(Subscriber!Focusable subscriber) {
        finished.subscribe(subscriber);
    }

    override void stopped() {
        super.stopped();
        finished(cast(Focusable) result);
    }

}

/// Set focus on the given node, if focusable, or the first of its focusable children. This will be done lazily during
/// the next draw.
///
/// If focusing the given node is not desired, use `focusRecurseChildren`.
///
/// Params:
///     parent = Container node to search in.
FocusRecurseAction focusRecurse(Node parent) {

    auto action = new FocusRecurseAction;

    // Perform a tree action to find the child
    parent.queueAction(action);

    return action;

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

/// Set focus on the first of the node's focusable children. This will be done lazily during the next draw.
///
/// Params:
///     parent = Container node to search in.
FocusRecurseAction focusRecurseChildren(Node parent) {

    auto action = new FocusRecurseAction;
    action.excludeStartNode = true;
    parent.queueAction(action);

    return action;

}

/// ditto
FocusRecurseAction focusChild(Node parent) {

    return focusRecurseChildren(parent);

}

@("FocusRecurse works")
unittest {

    import fluid.space;
    import fluid.button;

    auto root = vframeButton(
        button("", delegate { }),
        button("", delegate { }),
        delegate { }
    );

    // Typical focusRecurse call will focus the button
    root.focusRecurse;
    root.draw();

    assert(root.tree.focus is root);

    // If we want to make sure the action descends below the root, we must
    root.focusRecurseChildren;
    root.draw();

    assert(root.tree.focus.asNode is root.children[0]);

}

class FocusRecurseAction : FocusSearchAction {

    public {

        bool excludeStartNode;
        bool isReverse;
        void delegate(FluidFocusable) @safe finished;

    }

    override void beforeDraw(Node node, Rectangle) {

        // Ignore if the branch is disabled
        if (node.isDisabledInherited) return;

        // Ignore the start node if excluded
        if (excludeStartNode && node is startNode) return;

        // Check if the node is focusable
        if (auto focusable = cast(FluidFocusable) node) {

            // Mark the node
            result = node;

            // Stop here if selecting the first
            if (!isReverse) stop;

        }

    }

    override void stopped() {

        if (auto focusable = cast(FluidFocusable) result) {
            focusable.focus();
            if (finished) finished(focusable);
        }
        super.stopped();

    }

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

@("Legacy: ScrollIntoViewAction works (migrated)")
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
    assert(isClose(root.scroll, (root.maxScroll + 10) * 2/3 - 10));

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

/// Wait for the next frame. This action is a polyfill that can be used in tree action chains to make sure they're
/// added during `beforeTree`.
NextFrameAction nextFrame(Node node) {

    auto action = new NextFrameAction;
    node.startAction(action);
    return action;

}

class NextFrameAction : TreeAction {

    // Yes! It's that simple!

}
