///
module fluid.frame;

import std.meta;

import fluid.node;
import fluid.space;
import fluid.style;
import fluid.utils;
import fluid.input;
import fluid.structs;
import fluid.backend;


@safe:


/// Make a Frame node accept nodes via drag & drop.
///
/// Note: Currently, not all Frames support drag & drop. Using it for nodes that doesn't explicitly state support might
/// cause undefined behavior.
///
/// Params:
///     Node     = Require dropped nodes to be of given type.
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

/// Make a new vertical frame.
alias vframe = simpleConstructor!Frame;

/// Make a new horizontal frame.
alias hframe = simpleConstructor!(Frame, (a) {

    a.directionHorizontal = true;

});

/// This is a frame, a stylized container for other nodes.
///
/// Frame supports drag & drop via `acceptDrop`.
class Frame : Space, FluidDroppable {

    public {

        /// If true, a drag & drop node hovers this frame.
        bool isDropHovered;

        /// Selector (same as in themes) used to decide which nodes can be dropped inside, defaults to none.
        Selector dropSelector = Selector.none;

        /// Position of the cursor, indicating the area of the drop.
        Vector2 dropCursor;

        /// Size of the droppable area.
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

        super.resizeImpl(availableSpace);

        // Hovered by a dragged node
        if (_queuedDrop) {

            // Apply queued changes
            dropSize = _queuedDropSize;
            _queuedDrop = false;

            if (isHorizontal)
                minSize.x += dropSize.x;
            else
                minSize.y += dropSize.y;

        }

        // Clear the drop size
        else dropSize = Vector2();

    }

    protected override void drawImpl(Rectangle outer, Rectangle inner) {

        const style = pickStyle();
        style.drawBackground(tree.io, outer);

        // Clear dropSize if dropping stopped
        if (!isDropHovered && dropSize != Vector2()) {

            _queuedDrop = false;
            updateSize();

        }

        _dropIndex = 0;

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

    /// Drag and drop implementation: Offset nodes to provide space for the dropped node.
    protected Vector2 dropOffset(Vector2 offset) {

        // Ignore if nothing is dropped
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

    bool canDrop(Node node) {

        return dropSelector.test(node);

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

    }

}
