/// Frames place other nodes in a column or row.
///
/// A Frame can either be vertical and form a column, or horizontal and form a row. Use [vframe]
/// to create a vertical frame, or [hframe] to create a horizontal frame.
///
/// Frame can be made a target for drag-and-drop nodes using [acceptDrop].
///
/// `Frame` extends on, and adds functionality to otherwise very similar [Space].
/// See [fluid.space] for discussion of their differences.
module fluid.frame;

@safe:

///
@("Frame reference example")  // Example copied from space.d
unittest {
    import fluid.label;
    import fluid.button;

    // A vframe will align all its content in a column
    vframe(
        label("First entry"),
        label("Second entry"),
        label("Third entry"),
    );

    // hframe will lay out the nodes in a row
    hframe(
        label("One, "),
        label("Two, "),
        label("Three!"),
    );

    // Combine them to quickly build layouts!
    vframe(
        label("Are you sure you want to proceed?"),
        hframe(
            button("Yes", delegate { }),
            button("Cancel", delegate { }),
        ),
    );
}

/// [layout] can be used to divide a Frame into proportional segments.
@("Frame+layout example")
unittest {
    import fluid.label;
    run(
        // The sum of layout values is the denominator: 1+2 = 3
        hframe(
            label(
                // 1/(1+2) = 1/3
                .layout!1,
                "One third"
            ),
            label(
                // 2/(1+2) = 2/3
                .layout!2,
                "Two thirds"
            ),
        )
    );
}

import std.meta;

import fluid.node;
import fluid.space;
import fluid.style;
import fluid.utils;
import fluid.input;
import fluid.structs;

import fluid.io.canvas;

/// Make a [Frame] node accept nodes via drag & drop.
///
/// Note:
///     Fluid features other nodes that extend from Frame, but don't support drag & drop.
///     Using `acceptDrop` for nodes that doesn't explicitly state support might cause
///     undefined behavior.
///
///     Note that in the future, this functionality [will be moved to a separate
///     node](https://git.samerion.com/Samerion/Fluid/issues/297) to avoid this issue.
///
/// Params:
///     N        = Require dropped nodes to be of given type.
///     tags     = Restrict dropped nodes to those that have the given tag.
///     selector = Selector to limit nodes that the frame accepts. Optional — Tags are often enough.
auto acceptDrop(tags...)(Selector selector = Selector.init)
if (allSatisfy!(isNodeTag, tags)) {
    struct AcceptDrop {
        Selector selector;

        void apply(Frame frame) {
            frame.dropSelector = selector;
        }
    }

    return AcceptDrop(selector.addTags!tags);
}

/// ditto
auto acceptDrop(N, tags...)()
if (is(N : Node) && allSatisfy!(isNodeTag, tags)) {
    auto selector = Selector(typeid(N));
    return acceptDrop!(tags)(selector);
}

/// Make a new vertical frame. A vertical frame aligns child nodes in a column.
alias vframe = nodeBuilder!Frame;

/// A vframe places nodes vertically, so they appear on top of each other.
@("vframe example")
unittest {
    import fluid.label;

    vframe(
        label("Top node"),
        label("Middle node"),
        label("Bottom node"),
    );
}

/// Make a new horizontal frame. A horizontal frame aligns child nodes in a row.
alias hframe = nodeBuilder!(Frame, (a) {
    a.directionHorizontal = true;
});

/// A hframe places nodes horizontally, so they appear next to each other.
@("hframe example")
unittest {
    import fluid.label;

    hframe(label("Left node"), label("Center node"), label("Right node"));
}

/// This is a frame, a stylized container for other nodes.
///
/// Frame supports drag & drop via [acceptDrop].
class Frame : Space, FluidDroppable {

    CanvasIO canvasIO;

    public {

        /// Drag-and-drop. This is set to true when the user hovers the frame while holding
        /// a node that can be dropped into this frame.
        ///
        /// This property can be used in styling to hint the player that whatever node they're
        /// dragging can be released and placed.
        bool isDropHovered;

        /// Drag-and-drop. [Selector][fluid.theme.Selector] used to decide which nodes can be
        /// dropped inside the frame. The default value is `none`: no node can be dropped into
        /// this frame.
        Selector dropSelector = Selector.none;

        /// Drag-and-drop. If Frame is drop hovered ([isDropHovered]), `dropCursor` is the
        /// position of the hovering pointer, and is used to calculate where. Position is
        /// specified in screen coordinates (`(0, 0)` is the top-left corner of the window).
        Vector2 dropCursor;

        /// Drag-and-drop. If Frame is drop hovered ([isDropHovered]), this property is set to the
        /// size of the node hanging above the frame.
        Vector2 dropSize;

    }

    private {

        /// Index of the dropped node.
        size_t _dropIndex;

        bool _queuedDrop;

        /// `dropSize` to activate after a resize.
        Vector2 _queuedDropSize;

    }

    this(T...)(T args) {
        super(args);
    }

    protected override void resizeImpl(Vector2 availableSpace) {
        use(canvasIO);
        super.resizeImpl(availableSpace);

        // Hovered by a dragged node
        if (_queuedDrop || isDropHovered) {

            // Apply queued changes
            dropSize = _queuedDropSize;
            _queuedDrop = false;

            if (isHorizontal)
                minSize.x += dropSize.x;
            else
                minSize.y += dropSize.y;

        }

        // Clear the drop size
        else {
            dropSize = Vector2();
        }
    }

    protected override void drawImpl(Rectangle outer, Rectangle inner) {
        const style = pickStyle();
        style.drawBackground(canvasIO, outer);

        if (isDropHovered) {
            _dropIndex = 0;
        }

        // Clear dropSize if dropping stopped
        else if (dropSize != Vector2()) {
            _queuedDrop = false;
            updateSize();
        }

        // Provide offset for the drop item if it's the first node
        auto innerStart = dropOffset(start(inner));
        inner.x = innerStart.x;
        inner.y = innerStart.y;

        // Draw
        super.drawImpl(outer, inner);

        // Clear dropHovered status
        isDropHovered = false;
    }

    protected override bool hoveredImpl(Rectangle rect, Vector2 mousePosition) {
        import fluid.node;
        return Node.hoveredImpl(rect, mousePosition);
    }

    protected override Vector2 childOffset(Vector2 currentOffset, Vector2 childSpace) {
        const newOffset = super.childOffset(currentOffset, childSpace);

        // Take drop nodes into account
        return dropOffset(newOffset);
    }

    /// Drag-and-drop. Add offset to child nodes to make space for dragged node.
    /// This is called from [childOffset].
    ///
    /// Params:
    ///     offset = Original offset applied to the child, in screen space.
    /// Returns:
    ///     Position, either exactly as given, or offset by [dropSize] on one axis.
    protected Vector2 dropOffset(Vector2 offset) {
        if (!isDropHovered) return offset;

        const dropsHere = isHorizontal
            ? dropCursor.x <= offset.x + dropSize.x
            : dropCursor.y <= offset.y + dropSize.y;

        // Not dropping here
        if (!dropsHere && children.length) {
            _dropIndex++;
            return offset;
        }

        // Finish the drop event
        isDropHovered = false;

        // Increase the offset to fit the node
        return isHorizontal
            ? offset + Vector2(dropSize.x, 0)
            : offset + Vector2(0, dropSize.y);
    }

    /// Returns:
    ///     `true` if the given node can be dropped into this frame.
    ///
    ///     No node can be dropped into a frame that is disabled.
    bool canDrop(Node node) {
        return dropSelector.test(node)
            && !isDisabledInherited;
    }

    void dropHover(Vector2 position, Rectangle rectangle) {
        import std.math;

        isDropHovered = true;
        _queuedDrop = true;

        // Queue up the changes
        dropCursor = position;
        _queuedDropSize = size(rectangle);

        const same = isClose(dropSize.x, _queuedDropSize.x)
            && isClose(dropSize.y, _queuedDropSize.y);

        // Updated
        if (!same) updateSize();
    }

    void drop(Vector2 position, Rectangle rectangle, Node node) {
        import std.array;

        // Prevent overflow
        // This might happen when rearranging an item to the end within the same container
        if (_dropIndex > children.length)
            _dropIndex = children.length;

        this.children.insertInPlace(_dropIndex, node);
        updateSize();
    }

}
