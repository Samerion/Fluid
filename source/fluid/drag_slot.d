module fluid.drag_slot;

import std.array;
import std.range;

import fluid.tree;
import fluid.node;
import fluid.slot;
import fluid.input;
import fluid.utils;
import fluid.style;
import fluid.backend;
import fluid.structs;

import fluid.io.hover;
import fluid.io.canvas;

import fluid.future.context;

@safe:

/// A drag slot is a node slot providing drag & drop functionality.
alias dragSlot = simpleConstructor!DragSlot;

/// ditto
class DragSlot : NodeSlot!Node, FluidHoverable, Hoverable {

    mixin makeHoverable;
    mixin FluidHoverable.enableInputActions;
    mixin Hoverable.enableInputActions;

    HoverIO hoverIO;

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

        /// All I/O systems active on the last draw.
        Appender!(TreeIOContext.IOInstance[]) _ioSystems;

    }

    /// Create a new drag slot and place a node inside of it.
    this(Node node = null) {

        super(node);
        this.handle = dragHandle(.layout!"fill");

    }

    override bool blocksInput() const {
        return isDisabled || isDisabledInherited;
    }

    /// If true, this node is currently being dragged.
    bool isDragged() const {

        return dragAction !is null;

    }

    /// Drag the node.
    @(FluidInputAction.press, .WhileDown)
    void drag(Pointer pointer)
    in (tree)
    do {

        // Ignore if already dragging
        if (dragAction) {
            dragAction._stopDragging = false;
            dragAction.pointerPosition = pointer.position;
        }

        // Queue the drag action
        else {
            dragAction = new DragAction(this, pointer.position);
            if (hoverIO) {
                auto hover = cast(Node) hoverIO;
                hover.startAction(dragAction);
            }
            else {
                tree.queueAction(dragAction);
            }
            updateSize();
        }

    }

    /// Drag the node.
    @(FluidInputAction.press, .WhileDown)
    void drag()
    in (tree)
    do {

        // Polyfill for old backend-based I/O
        if (!hoverIO) {
            Pointer pointer;
            pointer.position = io.mousePosition;
            drag(pointer);
        }

    }

    private Rectangle dragRectangle(Vector2 offset) const {

        const position = _staticPosition + offset;

        return Rectangle(position.tupleof, _size.tupleof);

    }

    private void drawDragged(Node parent, Vector2 offset) {

        const rect = dragRectangle(offset);

        _drawDragged = true;
        minSize = _size;
        scope (exit) _drawDragged = false;
        scope (exit) minSize = Vector2(0, 0);

        parent.drawChild(this, rect);

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

        use(hoverIO);

        // Save active I/O systems
        _ioSystems.clear();
        put(_ioSystems, treeContext.io[]);

        // Resize the slot
        super.resizeImpl(available);

        // Resize the handle
        resizeChild(handle, available);

        // Add space for the handle
        if (!handle.isHidden) {

            minSize.y += handle.minSize.y + style.gap.sideY;

            if (handle.minSize.x > minSize.x) {
                minSize.x = handle.minSize.x;
            }

        }

    }

    private void resizeInternal(Node parent, Vector2 space) {

        _drawDragged = true;
        scope (exit) _drawDragged = false;

        parent.resizeChild(this, space);

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
        if (!handle.isHidden) {
            valueRect.y += handleWidth + style.gap.sideY;
            valueRect.h -= handleWidth + style.gap.sideY;
        }

        // Disable the children while dragging
        const disable = _drawDragged && !tree.isBranchDisabled;

        if (disable) tree.isBranchDisabled = true;

        // Draw the value
        super.drawImpl(outer, valueRect);

        if (disable) tree.isBranchDisabled = false;

        // Draw the handle
        drawChild(handle, handleRect);

    }

    protected override bool hoveredImpl(Rectangle rect, Vector2 position) {

        return Node.hoveredImpl(rect, position);

    }

    override bool isHovered() const {

        return this is tree.hover || super.isHovered();

    }

    void mouseImpl() {

    }

    bool hoverImpl() {
        return false;
    }

}

/// Draggable handle.
alias dragHandle = simpleConstructor!DragHandle;

/// ditto
class DragHandle : Node {

    CanvasIO canvasIO;

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

        use(canvasIO);
        minSize = Vector2(width * 2, width);

    }

    override void drawImpl(Rectangle outer, Rectangle inner) {

        const width = this.width;

        const radius = width / 2f;
        const circleVec = Vector2(radius, radius);
        const color = style.lineColor;
        const fill = style.cropBox(inner, [radius, radius, 0, 0]);

        if (canvasIO) {
            canvasIO.drawCircle(start(inner) + circleVec, radius, color);
            canvasIO.drawCircle(end(inner) - circleVec, radius, color);
            canvasIO.drawRectangle(fill, color);
        }
        else {
            io.drawCircle(start(inner) + circleVec, radius, color);
            io.drawCircle(end(inner) - circleVec, radius, color);
            io.drawRectangle(fill, color);
        }

    }

}

class DragAction : TreeAction {

    public {

        DragSlot slot;
        Vector2 mouseStart;
        FluidDroppable target;
        Rectangle targetRectangle;

        /// Current position of the pointer seen by the action.
        Vector2 pointerPosition;

        /// I/O context for the node while it is mid-air.
        ///
        /// This preserves the I/O stack that was active for the drag slot when the gesture started.
        TreeIOContext io;

    }

    private {

        bool _stopDragging;
        bool _readyToDrop;

    }

    deprecated this(DragSlot slot) {
        this(slot, slot.io.mousePosition);
    }

    this(DragSlot slot, Vector2 pointerPosition) {
        this.slot = slot;
        this.pointerPosition = pointerPosition;
        this.mouseStart = pointerPosition;
        this.io = TreeIOContext(slot._ioSystems[].assumeSorted);
    }

    Vector2 offset() const {

        return pointerPosition - mouseStart;

    }

    Rectangle relativeDragRectangle() {

        const rect = slot.dragRectangle(offset);

        return Rectangle(
            (rect.start - targetRectangle.start).tupleof,
            rect.size.tupleof,
        );

    }

    override void beforeTree(Node, Rectangle) {

        // Clear the target
        target = null;

    }

    override void beforeResize(Node node, Vector2 space) {

        auto regularIOContext = slot.treeContext.io;

        // Resize inside the start node, or inside the root if there isn't one
        const condition = startNode
            ? startNode.opEquals(node)
            : node is node.tree.root;

        if (condition) {

            // Swap the I/O context for the node
            node.treeContext.io = this.io;
            scope (exit) node.treeContext.io = regularIOContext;

            slot.resizeInternal(node, space);

        }

    }

    override void beforeDraw(Node node, Rectangle rectangle, Rectangle outer, Rectangle inner) {

        auto droppable = cast(FluidDroppable) node;

        // Find all hovered droppable nodes
        if (!droppable) return;
        // TODO modal support?
        if (!node.inBounds(outer, inner, pointerPosition)) return;

        // Make sure this slot can be dropped in
        if (!droppable.canDrop(slot)) return;

        this.target = droppable;
        this.targetRectangle = rectangle;

        droppable.dropHover(pointerPosition, relativeDragRectangle);

    }

    override void afterDraw(Node node, Rectangle space) {

        if (startNode && startNode.opEquals(node)) {
            drawSlot(node);
        }

    }

    /// Tree drawn, draw the node now.
    override void afterTree() {

        if (startNode is null) {
            drawSlot(slot.tree.root);
        }

    }

    void drawSlot(Node parent) {

        // Draw the slot
        slot.drawDragged(parent, offset);

    }

    /// Process input.
    override void afterInput(ref bool focusHandled) {

        // We should have received a signal from the slot if it is still being dragged
        if (!_stopDragging) {
            _stopDragging = true;
            return;
        }

        // Drop the slot if a droppable node was found
        if (target) {

            // Ready to drop, perform the action
            if (_readyToDrop) {

                target.drop(pointerPosition, relativeDragRectangle, slot);

            }

            // Remove it from the original container and wait a frame
            else {

                slot.toRemove = true;
                _readyToDrop = true;
                return;

            }

        }

        // Stop dragging
        slot.dragAction = null;
        slot.updateSize();
        stop;

    }

}
