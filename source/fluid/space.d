///
module fluid.space;

import std.math;
import std.range;
import std.string;
import std.traits;
import std.algorithm;

import fluid.node;
import fluid.style;
import fluid.utils;
import fluid.backend;
import fluid.children;


@safe:


/// This is a space, a basic container for other nodes.
///
/// Nodes are laid in a column (`vframe`) or in a row (`hframe`).
///
/// Space only acts as a container and doesn't implement styles and doesn't take focus. It's very useful as a helper for
/// building layout, while `Frame` remains to provide styling.
alias vspace = simpleConstructor!Space;

/// ditto
alias hspace = simpleConstructor!(Space, (a) {

    a.directionHorizontal = true;

});

/// ditto
class Space : Node {

    mixin DefineStyles;

    public {

        /// Children of this frame.
        Children children;

        /// Defines in what directions children of this frame should be placed.
        ///
        /// If true, children are placed horizontally, if false, vertically.
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

    // Generate constructors
    deprecated("Use this(NodeParams params, Node[] nodes...) instead") {

        static foreach (index; 0 .. BasicNodeParamLength) {

            this(BasicNodeParam!index params, Node[] nodes...) {

                super(params);
                this.children ~= nodes;

            }

        }

    }

    this(NodeParams params, Node[] nodes...) {

        super(params);
        this.children ~= nodes;

    }

    this() {

    }

    /// Add children.
    pragma(inline, true)
    void opOpAssign(string operator : "~", T)(T nodes) {

        children ~= nodes;

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
        foreach (child; children) {

            // This node expands and isn't hidden
            if (child.layout.expand && !child.isHidden) {

                // Make it happen later
                expandChildren ~= child;

                // Add to the denominator
                denominator += child.layout.expand;

            }

            // Check non-expand nodes now
            else {

                child.resize(tree, theme, childSpace(child, available, false));
                minSize = childPosition(child.minSize, minSize);

                // Reserve space for this node
                reservedSpace += directionHorizontal
                    ? child.minSize.x
                    : child.minSize.y;

            }

        }

        // Calculate the size of expanding children last
        foreach (child; expandChildren) {

            // Resize the child
            child.resize(tree, theme, childSpace(child, available, false));

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
        minSize = childPosition(expandSize, minSize);

    }

    protected override void drawImpl(Rectangle, Rectangle area) {

        assertClean(children, "Children were changed without calling updateSize().");

        auto position = Vector2(area.x, area.y);

        foreach (child; filterChildren) {

            // Get params
            const size = childSpace(child, Vector2(area.width, area.height), true);
            const rect = Rectangle(
                position.x, position.y,
                size.x, size.y
            );

            // Draw the child
            child.draw(rect);

            // Offset position
            if (directionHorizontal) position.x += size.x;
            else position.y += size.y;

        }

    }

    /// List children in the space, removing all nodes queued for deletion beforehand.
    protected auto filterChildren() {

        struct ChildIterator {

            Space node;

            int opApply(int delegate(Node) @safe fun) @trusted {

                node.children.lock();
                scope (exit) node.children.unlock();

                size_t destinationIndex = 0;

                // Iterate through all children. When we come upon ones that are queued for deletion,
                foreach (sourceIndex, child; node.children) {

                    const toRemove = child.toRemove;
                    child.toRemove = false;

                    // Ignore children that are to be removed
                    if (toRemove) continue;

                    // Yield the child
                    const status = fun(child);

                    // Move the child if needed
                    if (sourceIndex != destinationIndex) {

                        node.children.forceMutable[destinationIndex] = child;

                    }

                    // Stop iteration if requested
                    else if (status) return status;

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

    /// Iterate over every child and perform the painting function. Will automatically remove nodes queued for removal.
    /// Returns: An iterator that goes over all nodes.
    deprecated("Use filterChildren instead")
    protected void drawChildren(void delegate(Node) @safe painter) {

        Node[] leftovers;

        children.lock();
        scope (exit) children.unlock();

        // Draw each child and get rid of removed children
        auto range = children[]

            // Check if the node is queued for removal
            .filter!((node) {
                const status = node.toRemove;
                node.toRemove = false;
                return !status;
            })

            // Draw the node
            .tee!((node) => painter(node));

        // Do what we ought to do
        () @trusted {

            // Process the children and move them back to the original array
            auto leftovers = range.moveAll(children.forceMutable);

            // Adjust the array size
            children.forceMutable.length -= leftovers.length;

        }();

    }

    protected override bool hoveredImpl(Rectangle, Vector2) const {

        return false;

    }

    protected override inout(Style) pickStyle() inout {

        return null;

    }

    /// Params:
    ///     child     = Child size to add.
    ///     previous  = Previous position.
    private Vector2 childPosition(Vector2 child, Vector2 previous) const {

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

    /// Get space for a child.
    /// Params:
    ///     child     = Child to place
    ///     available = Available space
    private Vector2 childSpace(const Node child, Vector2 available, bool stateful) const
    in(
        child.isHidden || child.layout.expand <= denominator,
        format!"Nodes %s/%s sizes are out of date, call updateSize after updating the tree or layout (%s/%s)"(
            typeid(this), typeid(child), child.layout.expand, denominator,
        )
    )
    out(
        r; [r.tupleof].all!isFinite,
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

///
unittest {

    import fluid;

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

unittest {

    class Square : Node {

        mixin implHoveredRect;

        Color color;

        this(Color color) {
            this.color = color;
        }

        override void resizeImpl(Vector2) {
            minSize = Vector2(50, 50);
        }

        override void drawImpl(Rectangle, Rectangle inner) {
            io.drawRectangle(inner, this.color);
        }

    }

    auto io = new HeadlessBackend;
    auto root = vspace(
        new Square(color!"000"),
        new Square(color!"001"),
        new Square(color!"002"),
        hspace(
            new Square(color!"010"),
            new Square(color!"011"),
            new Square(color!"012"),
        ),
    );

    root.io = io;
    root.theme = nullTheme;
    root.draw();

    // vspace
    io.assertRectangle(Rectangle(0,   0, 50, 50), color!"000");
    io.assertRectangle(Rectangle(0,  50, 50, 50), color!"001");
    io.assertRectangle(Rectangle(0, 100, 50, 50), color!"002");

    // hspace
    io.assertRectangle(Rectangle(  0, 150, 50, 50), color!"010");
    io.assertRectangle(Rectangle( 50, 150, 50, 50), color!"011");
    io.assertRectangle(Rectangle(100, 150, 50, 50), color!"012");

}

unittest {

    import fluid.frame;
    import fluid.structs;

    auto io = new HeadlessBackend;
    auto root = hspace(
        layout!"fill",
        vframe(layout!1),
        vframe(layout!2),
        vframe(layout!1),
    );

    root.io = io;
    root.theme = nullTheme.makeTheme!q{
        Frame.styleAdd.backgroundColor = color!"7d9";
    };

    // Frame 1
    {
        root.draw();
        io.assertRectangle(Rectangle(0,   0, 0, 0), color!"7d9");
        io.assertRectangle(Rectangle(200, 0, 0, 0), color!"7d9");
        io.assertRectangle(Rectangle(600, 0, 0, 0), color!"7d9");
    }

    // Fill all nodes
    foreach (child; root.children) {
        child.layout.nodeAlign = NodeAlign.fill;
    }
    root.updateSize();

    {
        io.nextFrame;
        root.draw();
        io.assertRectangle(Rectangle(  0, 0, 200, 600), color!"7d9");
        io.assertRectangle(Rectangle(200, 0, 400, 600), color!"7d9");
        io.assertRectangle(Rectangle(600, 0, 200, 600), color!"7d9");
    }

    const alignments = [NodeAlign.start, NodeAlign.center, NodeAlign.end];

    // Make Y alignment different across all three
    foreach (pair; root.children.zip(alignments)) {
        pair[0].layout.nodeAlign = pair[1];
    }

    {
        io.nextFrame;
        root.draw();
        io.assertRectangle(Rectangle(  0,   0, 0, 0), color!"7d9");
        io.assertRectangle(Rectangle(400, 300, 0, 0), color!"7d9");
        io.assertRectangle(Rectangle(800, 600, 0, 0), color!"7d9");
    }

}

unittest {

    import fluid.frame;
    import fluid.structs;

    auto io = new HeadlessBackend(Vector2(270, 270));
    auto root = hframe(
        layout!"fill",
        vspace(layout!2),
        vframe(
            layout!(1, "fill"),
            hspace(layout!2),
            hframe(
                layout!(1, "fill"),
                vframe(
                    layout!(1, "fill"),
                    hframe(
                        layout!(1, "fill")
                    ),
                    hspace(layout!2),
                ),
                vspace(layout!2),
            )
        ),
    );

    root.theme = nullTheme.makeTheme!q{
        Frame.styleAdd.backgroundColor = color!"0004";
    };
    root.io = io;
    root.draw();

    io.assertRectangle(Rectangle(  0,   0, 270, 270), color!"0004");
    io.assertRectangle(Rectangle(180,   0,  90, 270), color!"0004");
    io.assertRectangle(Rectangle(180, 180,  90,  90), color!"0004");
    io.assertRectangle(Rectangle(180, 180,  30,  90), color!"0004");
    io.assertRectangle(Rectangle(180, 180,  30,  30), color!"0004");

}

// https://git.samerion.com/Samerion/Fluid/issues/58
unittest {

    import fluid.frame;
    import fluid.label;
    import fluid.structs;

    auto fill = layout!(1, "fill");
    auto io = new HeadlessBackend;
    auto myTheme = nullTheme.makeTheme!q{
        Frame.styleAdd.backgroundColor = color!"#303030";
        Label.styleAdd.backgroundColor = color!"#e65bb8";
    };
    auto root = hframe(
        fill,
        myTheme,
        label(fill, "1"),
        label(fill, "2"),
        label(fill, "3"),
        label(fill, "4"),
        label(fill, "5"),
        label(fill, "6"),
        label(fill, "7"),
        label(fill, "8"),
        label(fill, "9"),
        label(fill, "10"),
        label(fill, "11"),
        label(fill, "12"),
    );

    root.io = io;
    root.draw();

    io.assertRectangle(Rectangle( 0*800/12f, 0, 66.66, 600), color!"#e65bb8");
    io.assertRectangle(Rectangle( 1*800/12f, 0, 66.66, 600), color!"#e65bb8");
    io.assertRectangle(Rectangle( 2*800/12f, 0, 66.66, 600), color!"#e65bb8");
    io.assertRectangle(Rectangle( 3*800/12f, 0, 66.66, 600), color!"#e65bb8");
    io.assertRectangle(Rectangle( 4*800/12f, 0, 66.66, 600), color!"#e65bb8");
    io.assertRectangle(Rectangle( 5*800/12f, 0, 66.66, 600), color!"#e65bb8");
    io.assertRectangle(Rectangle( 6*800/12f, 0, 66.66, 600), color!"#e65bb8");
    io.assertRectangle(Rectangle( 7*800/12f, 0, 66.66, 600), color!"#e65bb8");
    io.assertRectangle(Rectangle( 8*800/12f, 0, 66.66, 600), color!"#e65bb8");
    io.assertRectangle(Rectangle( 9*800/12f, 0, 66.66, 600), color!"#e65bb8");
    io.assertRectangle(Rectangle(10*800/12f, 0, 66.66, 600), color!"#e65bb8");
    io.assertRectangle(Rectangle(11*800/12f, 0, 66.66, 600), color!"#e65bb8");

}
