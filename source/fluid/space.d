/// Spaces create columns or rows of other nodes.
///
/// A Space can be either vertical (a column) or horizontal (a row). Use [vspace] to create a
/// vertical Space, and a [hspace] to create a horizontal Space.
///
/// Spaces are very similar to [Frames][fluid.frame.Frame]. For most purposes, Frames are
/// sufficient, but Space offers a shorthand:
///
/// * Spaces have no background,
/// * Spaces cannot be "clicked through": if a Space is drawn over other nodes, the nodes can
///   still be clicked,
///
/// Spaces are thus convenient to avoid some of Frame's side effects when only intended for
/// layout purposes.
///
/// On top of the above, Spaces currently do not support drag-and-drop, but Frames
/// do. A future update [will move drag-and-drop functionality into a separate
/// node](https://git.samerion.com/Samerion/Fluid/issues/297).
module fluid.space;

@safe:

///
unittest {
    import fluid.label;
    import fluid.button;

    // A vspace will align all its content in a column
    vspace(
        label("First entry"),
        label("Second entry"),
        label("Third entry"),
    );

    // hspace will lay out the nodes in a row
    hspace(
        label("One, "),
        label("Two, "),
        label("Three!"),
    );

    // Combine them to quickly build layouts!
    vspace(
        label("Are you sure you want to proceed?"),
        hspace(
            button("Yes", delegate { }),
            button("Cancel", delegate { }),
        ),
    );

}

/// Use spaces to organize your apps. For example, if you need to insert nodes into a column
/// on event, you can append them to a `Space`:
@("Space reference example")
unittest {
    import fluid.label;
    import fluid.frame;
    import fluid.button;
    import fluid.text_input;

    Space shoppingList;
    TextInput newItem;
    run(
        vframe(
            label("My shopping list:"),
            shoppingList = vspace(
                label("Apples"),
                label("Carrots"),
            ),
            hspace(
                newItem = textInput("Item..."),
                button("Add item", delegate {
                    shoppingList ~= label(newItem.value);
                }),
            ),
        ),
    );
}

import std.math;
import std.range;
import std.string;
import std.traits;
import std.algorithm;

import fluid.node;
import fluid.style;
import fluid.utils;
import fluid.children;

/// A [node builder][fluid.utils.nodeBuilder] that creates a vertical (`vspace`) or horizontal
/// Space (`hspace`).
alias vspace = nodeBuilder!Space;

/// ditto
alias hspace = nodeBuilder!(Space, (a) {
    a.directionHorizontal = true;
});

/// A container node that aligns its children in columns or rows.
class Space : Node {

    public {

        /// Nodes this space will align and display. They are contained inside the node.
        ///
        /// Adding and removing nodes will change the application's layout, so it is necessary
        /// to call [updateSize] on the `Space` afterwards.
        ///
        /// Because of how `Space` stores the children, it is also impossible to change `children`
        /// while drawing. Attempts to do so will be detected when compiling in debug mode.
        /// Detection is handled by [Children].
        Children children;

        /// If true, children are placed horizontally (in a row), if false, vertically
        /// (in a column).
        ///
        /// This can be controlled when constructing nodes by using [vspace] or [hspace].
        bool isHorizontal;

        alias horizontal = isHorizontal;
        alias directionHorizontal = horizontal;

    }

    private {

        /// Denominator for content sizing.
        uint denominator;

        /// Space reserved for shrinking elements.
        float reservedSpace;

    }

    /// Create the space and fill it with given nodes.
    /// Params:
    ///     nodes = Nodes for the space to control.
    this(Node[] nodes...) {
        this.children ~= nodes;
    }

    /// ditto
    this(T : Node)(T[] nodes...)
    if (!is(T[] : Node[])) {
        this.children ~= nodes;
    }

    /// Construct `Space` using node builders:
    @("Space node constructor demo")
    unittest {
        import fluid.label;
        run(
            vspace(
                label("Node 1"),
                label("Node 2"),
            ),
        );
    }

    /// Append children nodes to this node.
    ///
    /// This is the same as `node.children ~= nodes`, except it will automatically trigger
    /// a resize.
    ///
    /// Params:
    ///     nodes = Nodes to append.
    void opOpAssign(string operator : "~", T)(T nodes) {
        children ~= nodes;
        updateSize();
    }

    protected override void resizeImpl(Vector2 available) {

        import std.algorithm : max, map, fold;

        // Now that we're recalculating the layout, we can remove the dirty flag from children
        children.clearDirty;

        // Reset size
        minSize = Vector2(0, 0);
        reservedSpace = 0;
        denominator = 0;

        // Ignore the rest if there's no children
        if (!children.length) return;

        Vector2 maxExpandSize;

        // Collect expanding children in a separate array
        Node[] expandChildren;
        size_t visibleChildren;
        foreach (child; children) {

            visibleChildren += !child.isHidden;

            // This node expands and isn't hidden
            if (child.layout.expand && !child.isHidden) {

                // Make it happen later
                expandChildren ~= child;

                // Add to the denominator
                denominator += child.layout.expand;

            }

            // Check non-expand nodes now
            else {

                resizeChild(child, childSpace(child, available, false));
                minSize = addSize(child.minSize, minSize);

                // Reserve space for this node
                reservedSpace += directionHorizontal
                    ? child.minSize.x
                    : child.minSize.y;

            }

        }

        const gapSpace
            = visibleChildren == 0 ? 0
            : isHorizontal ? style.gap.sideX * (visibleChildren - 1u)
            :                style.gap.sideY * (visibleChildren - 1u);

        // Reserve space for gaps
        reservedSpace += gapSpace;

        if (isHorizontal)
            minSize.x += gapSpace;
        else
            minSize.y += gapSpace;

        // Calculate the size of expanding children last
        foreach (child; expandChildren) {

            // Resize the child
            resizeChild(child, childSpace(child, available, false));

            const childSize = child.minSize;
            const childExpand = child.layout.expand;

            const segmentSize = horizontal
                ? Vector2(childSize.x / childExpand, childSize.y)
                : Vector2(childSize.x, childSize.y / childExpand);

            // Reserve expand space
            maxExpandSize.x = max(maxExpandSize.x, segmentSize.x);
            maxExpandSize.y = max(maxExpandSize.y, segmentSize.y);

        }

        const expandSize = horizontal
            ? Vector2(maxExpandSize.x * denominator, maxExpandSize.y)
            : Vector2(maxExpandSize.x, maxExpandSize.y * denominator);

        // Add the expand space
        minSize = addSize(expandSize, minSize);

    }

    protected override void drawImpl(Rectangle, Rectangle inner) {
        drawChildren(inner);
    }

    /// Draw all of the space's children.
    ///
    /// This function is only to be called from within `drawImpl` of nodes that inherit
    /// from `Space`. Use this if you're making modifications to `Space`'s behavior.
    ///
    /// It's illegal to change the children while this function is running. This is because
    /// any node that is marked for removal will be removed from [children] during iteration.
    /// This is done in place by shifting all subsequent siblings leftwards.
    ///
    /// For example, if node 3 is marked for removal: `[1, 2, 3, 4, 5]`, during iteration
    /// it will be overridden by a following node: `[1, 2, 4, 5, 5]`. "Leftovers" at the end of
    /// the array will be removed when the last node is reached: `[1, 2, 4, 5]`.
    ///
    /// Params:
    ///     inner = Rectangle to draw the children in.
    ///         `Space` normally draws inside the content box (inner).
    protected void drawChildren(Rectangle inner) {

        assertClean(children, "Children were changed without calling updateSize().");

        auto position = start(inner);
        Node[] nodes = children[];
        size_t destinationIndex = 0;

        // Prevent modifications while running
        {
            children.lock();
            scope (exit) children.unlock();

            foreach (sourceIndex, child; nodes) {

                const toRemove = child.toRemove;
                child.toRemove = false;

                // Ignore children that are to be removed
                if (toRemove) continue;

                position = drawNextChild(inner, position, child);

                // Move children if needed
                if (sourceIndex != destinationIndex) {
                    nodes[destinationIndex] = child;
                }

                // Set space for next nodes
                destinationIndex++;

            }
        }

        // Remove leftovers
        nodes.length = destinationIndex;
        assertClean(children, "Children were changed without calling updateSize().");
        children = nodes;
        children.clearDirty;

    }

    /// Draw a child node and lay it out according to Space's rules.
    ///
    /// This function is only to be called from within `drawImpl` of nodes that inherit
    /// from `Space`. Use this if you're making modifications to `Space`'s behavior.
    ///
    /// Params:
    ///     inner = Rectangle to draw the children in.
    ///     start = Position to draw the child node on; this will be the node's top-left corner.
    ///     child = Child node to draw.
    /// Returns:
    ///     Position of the next node.
    protected Vector2 drawNextChild(Rectangle inner, Vector2 start, Node child) {

        // Ignore if this child is not visible
        if (child.isHidden) return start;

        // Get params
        const available = size(inner);
        const size = childSpace(child, available, true);
        const rect = Rectangle(start.tupleof, size.tupleof);

        // Draw the child
        drawChild(child, rect);

        // Offset position
        return childOffset(start, size);

    }

    // Deliberately left undocumented, it will become obsolete:
    // https://git.samerion.com/Samerion/Fluid/issues/453
    protected auto filterChildren() {

        struct ChildIterator {

            Space node;

            int opApply(int delegate(Node) @safe fun) @trusted {

                foreach (_, node; this) {

                    if (auto result = fun(node)) {
                        return result;
                    }

                }
                return 0;

            }

            int opApply(int delegate(size_t index, Node) @safe fun) @trusted {

                node.children.lock();
                scope (exit) node.children.unlock();

                size_t destinationIndex = 0;
                int end = 0;

                // Iterate through all children
                foreach (sourceIndex, child; node.children) {

                    const toRemove = child.toRemove;
                    child.toRemove = false;

                    // Ignore children that are to be removed
                    if (toRemove) continue;

                    // Yield the child
                    if (!end)
                        end = fun(destinationIndex, child);

                    // Move the child if needed
                    if (sourceIndex != destinationIndex) {

                        node.children.forceMutable[destinationIndex] = child;

                    }

                    // Stop iteration if requested — and if there's nothing to move
                    else if (end) return end;

                    // Set space for next nodes
                    destinationIndex++;


                }

                // Adjust length
                node.children.forceMutable.length = destinationIndex;

                return 0;

            }

        }

        return ChildIterator(this);

    }

    /// `Space` does not take hover. Clicking will always "pass through" the `Space`, activating
    /// nodes underneath it, if any.
    /// Returns:
    ///     False, always.
    protected override bool hoveredImpl(Rectangle, Vector2) {
        return false;
    }

    /// Params:
    ///     child     = Child size to add.
    ///     previous  = Previous position.
    private Vector2 addSize(Vector2 child, Vector2 previous) const {

        import std.algorithm : max;

        // Horizontal
        if (directionHorizontal) {

            return Vector2(
                previous.x + child.x,
                max(minSize.y, child.y),
            );

        }

        // Vertical
        else return Vector2(
            max(minSize.x, child.x),
            previous.y + child.y,
        );

    }

    /// Calculate the offset for the next node, given the `childSpace` result for its previous sibling.
    protected Vector2 childOffset(Vector2 currentOffset, Vector2 childSpace) {

        if (isHorizontal)
            return currentOffset + Vector2(childSpace.x + style.gap.sideX, 0);
        else
            return currentOffset + Vector2(0, childSpace.y + style.gap.sideY);

    }

    /// Get space for a child.
    /// Params:
    ///     child     = Child to place
    ///     available = Available space
    ///     stateful  = .
    protected Vector2 childSpace(const Node child, Vector2 available, bool stateful = true) const
    in(
        child.isHidden || child.layout.expand <= denominator,
        format!"Nodes %s/%s sizes are out of date, call updateSize after updating the tree or layout (%s/%s)"(
            typeid(this), typeid(child), child.layout.expand, denominator,
        )
    )
    out(
        r; only(r.tupleof).all!isFinite,
        format!"space: child %s given invalid size %s. available = %s, expand = %s, denominator = %s, reserved = %s"(
            typeid(child), r, available, child.layout.expand, denominator, reservedSpace
        )
    )
    do {

        // Hidden, give it no space
        if (child.isHidden) return Vector2();

        // Horizontal
        if (directionHorizontal) {

            const avail = (available.x - reservedSpace);
            const minSize = stateful
                ? child.minSize.x
                : available.x;

            return Vector2(
                child.layout.expand
                    ? avail * child.layout.expand / denominator
                    : minSize,
                available.y,
            );

        }

        // Vertical
        else {

            const avail = (available.y - reservedSpace);
            const minSize = stateful
                ? child.minSize.y
                : available.y;

            return Vector2(
                available.x,
                child.layout.expand
                    ? avail * child.layout.expand / denominator
                    : minSize,
            );

        }

    }

}
