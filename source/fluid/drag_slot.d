module fluid.drag_slot;

import fluid.tree;
import fluid.node;
import fluid.slot;
import fluid.input;
import fluid.utils;
import fluid.style;
import fluid.backend;
import fluid.structs;


@safe:


/// A drag slot is a node slot providing drag & drop functionality.
alias dragSlot = simpleConstructor!DragSlot;

/// ditto
class DragSlot : NodeSlot!Node, FluidHoverable {

    mixin makeHoverable;
    mixin enableInputActions;

    public {

        DragHandle handle;

        /// Current drag action, if applicable.
        DragAction dragAction;

    }

    private {

        bool _drawDragged;

        /// Size used while the slot is being dragged.
        Vector2 _size;

        /// Last position when drawing statically (not dragging).
        Vector2 _staticPosition;

    }

    /// Create a new drag slot and place a node inside of it.
    this(Node node = null) {

        super(node);
        this.handle = dragHandle(.layout!"fill");

    }

    /// If true, this node is currently being dragged.
    bool isDragged() const {

        return dragAction !is null;

    }

    /// Drag the node.
    /// Returns: `DragAction` responsible for the movement, or `null` if the node is already being dragged.
    @(FluidInputAction.press, .whileDown)
    DragAction drag()
    in (tree)
    do {

        // Ignore if already dragging
        if (dragAction) {

            dragAction._stopDragging = false;
            return null;

        }

        // Queue the drag action
        dragAction = new DragAction(this);
        queueAction(dragAction);
        updateSize();

        return dragAction;

    }

    private void drawDragged(Vector2 offset) {

        const position = _staticPosition + offset;
        const rect = Rectangle(position.tupleof, _size.tupleof);

        _drawDragged = true;
        minSize = _size;
        scope (exit) _drawDragged = false;
        scope (exit) minSize = Vector2(0, 0);

        draw(rect);

    }

    alias isHidden = typeof(super).isHidden;

    @property
    override bool isHidden() const scope {

        // Don't hide from the draw action
        if (_drawDragged)
            return super.isHidden;

        // Hide the node from its parent if it's dragged
        else return super.isHidden || isDragged;

    }

    override void resizeImpl(Vector2 available) {

        // Resize the slot
        super.resizeImpl(available);

        // Resize the handle
        handle.resize(tree, theme, available);

        // Add space for the handle
        minSize.y += handle.minSize.y + style.gap;

        if (handle.minSize.x > minSize.x) {
            minSize.x = handle.minSize.x;
        }

    }

    private void resizeInternal(LayoutTree* tree, Theme theme, Vector2 space) {

        _drawDragged = true;
        scope (exit) _drawDragged = false;

        resize(tree, theme, space);

        // Save the size
        _size = minSize;

    }

    override void drawImpl(Rectangle outer, Rectangle inner) {

        const handleWidth = handle.minSize.y;

        auto style = pickStyle;
        auto handleRect = inner;
        auto valueRect = inner;

        // Save position
        if (!_drawDragged)
            _staticPosition = start(outer);

        // Split the inner rectangle to fit the handle
        handleRect.h = handleWidth;
        valueRect.y += handleWidth + style.gap;
        valueRect.h -= handleWidth + style.gap;

        // Draw the value
        super.drawImpl(outer, valueRect);

        // Draw the handle
        handle.draw(handleRect);

    }

    override bool isHovered() const {

        return this is tree.hover || super.isHovered();

    }

    void mouseImpl() {

    }

}

/// Draggable handle.
alias dragHandle = simpleConstructor!DragHandle;

/// ditto
class DragHandle : Node {

    /// Additional features available for drag handle styling
    static class Extra : typeof(super).Extra {

        /// Width of the draggable bar
        float width;

        this(float width) {

            this.width = width;

        }

    }

    /// Get the width of the bar.
    float width() const {

        const extra = cast(const Extra) style.extra;

        if (extra)
            return extra.width;
        else
            return 0;

    }

    override bool hoveredImpl(Rectangle, Vector2) {

        return false;

    }

    override void resizeImpl(Vector2 available) {

        minSize = Vector2(width * 2, width);

    }

    override void drawImpl(Rectangle outer, Rectangle inner) {

        const width = this.width;

        const radius = width / 2f;
        const circleVec = Vector2(radius, radius);
        const color = style.lineColor;
        const fill = style.cropBox(inner, [radius, radius, 0, 0]);

        io.drawCircle(start(inner) + circleVec, radius, color);
        io.drawCircle(end(inner) - circleVec, radius, color);
        io.drawRectangle(fill, color);

    }

}

class DragAction : TreeAction {

    public {

        DragSlot slot;
        Vector2 mouseStart;

    }

    private {

        bool _stopDragging;

    }

    this(DragSlot slot) {

        this.slot = slot;
        this.mouseStart = slot.io.mousePosition;

    }

    override void beforeResize(Node node, Vector2 viewportSize) {

        // Only accept root resizes
        if (node !is node.tree.root) return;

        // Perform the resize
        slot.resizeInternal(node.tree, node.theme, viewportSize);

    }

    /// Tree drawn, draw the node now.
    override void afterTree() {

        // Stop if the node requested removal
        if (slot.toRemove) return stop;

        // Draw the slot
        slot.drawDragged(slot.io.mousePosition - mouseStart);
        _stopDragging = true;

    }

    /// Process input.
    override void afterInput(ref bool focusHandled) {

        // We should have received a signal from the slot if it is still being dragged
        if (_stopDragging) {

            // Nope, stop dragging
            slot.dragAction = null;
            slot.updateSize();
            return stop;

        }

    }

}
