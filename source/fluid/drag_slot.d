/// [DragSlot] is a node that can be dragged by the user, and then dropped into another location
/// in the node tree.
///
/// It can be constructed using [dragSlot] node builder.
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
import fluid.frame : acceptDrop;

import fluid.io.hover;
import fluid.io.canvas;
import fluid.io.overlay;

import fluid.future.context;

@safe:

/// [Node builder][nodeBuilder] for [DragSlot]. The constructor accepts a single but optional
/// node to place inside the slot.
alias dragSlot = nodeBuilder!DragSlot;

/// [NodeSlot] variant that can be dragged by the user and dropped into another node.
///
/// A handle is added inside which provides space for the user to drag, but it can be hidden;
/// any space in the slot, unless blocked by a child, can be used to drag the node. See
/// [handle][DragSlot.handle] for more information.
///
/// While dragged, `DragSlot` is moved into [OverlayIO] and remains there until dropped.
/// `DragSlot` can be dropped into [FluidDroppable] nodes if it fulfills the node's conditions;
/// see [fluid.frame.acceptDrop] for using [Frame][fluid.frame] as a drag & drop target.
///
/// Note that drag & drop can only be controlled using mouse or other hover devices; alternative
/// controls should be provided for keyboard and gamepad controls.
///
/// `DragSlot` is a bit out of date in terms of common practices in Fluid, and doesn't serve
/// as a good example of how nodes can be written, but should remain useful as a standalone node.
class DragSlot : NodeSlot!Node, FluidHoverable, Hoverable {

    mixin makeHoverable;
    mixin FluidHoverable.enableInputActions;
    mixin Hoverable.enableInputActions;

    HoverIO hoverIO;
    OverlayIO overlayIO;

    public {

        ///
        DragHandle handle;

        /// Current drag action, if applicable.
        DragAction dragAction;

        /// If used with `OverlayIO`, this node wraps the drag slot to provide the overlay.
        DragSlotOverlay overlay;

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
        this.overlay = new DragSlotOverlay(this);

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
    void drag(HoverPointer pointer)
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
            if (overlayIO) {
                overlayIO.addOverlay(overlay, OverlayIO.types.draggable);
            }
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
            HoverPointer pointer;
            pointer.position = io.mousePosition;
            drag(pointer);
        }

    }

    private Rectangle dragRectangle(Vector2 offset) const nothrow {
        const position = _staticPosition + offset;
        return Rectangle(position.tupleof, _size.tupleof);
    }

    private void drawDragged(Node parent, Rectangle rect) {

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
        use(overlayIO);

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

    bool hoverImpl(HoverPointer) {
        return false;
    }

    alias opEquals = typeof(super).opEquals;

    override bool opEquals(const Object other) const {
        return super.opEquals(other);
    }

}

/// Wraps the `DragSlot` while it is being dragged.
///
/// This is used to detect when `DragSlot` is drawn as an overlay or not. The `DragSlotOverlay`
/// is passed to `OverlayIO`, so it is known that if drawn, `DragSlotOverlay` functions
/// as an overlay.
///
/// **`DragSlotOverlay` does not offer a stable interface.** It may only be a temporary solution
/// for the detection problem, before a more general option is added for `OverlayIO`.
class DragSlotOverlay : Node, Overlayable {

    DragSlot next;

    this(DragSlot next = null) {
        this.next = next;
    }

    override void resizeImpl(Vector2 space) {
        next.resizeInternal(this, space);
        minSize = next.minSize;
    }

    override void drawImpl(Rectangle, Rectangle inner) {
        next.drawDragged(this, inner);
    }

    override Rectangle getAnchor(Rectangle) const nothrow {

        // backwards compatibility
        import std.exception : assumeWontThrow;

        if (next.dragAction) {
            const position = next._staticPosition + next.dragAction.offset.assumeWontThrow;
            return Rectangle(position.tupleof, 0, 0);
        }

        // Not dragged, no valid anchor
        else return Rectangle.init;

    }

    alias opEquals = typeof(super).opEquals;

    override bool opEquals(const Object other) const {
        return super.opEquals(other);
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

        // Reside only if OverlayIO is not in use
        if (slot.overlayIO is null && node is node.tree.root) {
            slot.resizeInternal(node, space);
        }

    }

    override void beforeDraw(Node node, Rectangle rectangle, Rectangle outer, Rectangle inner) {

        auto droppable = cast(FluidDroppable) node;

        // Find all hovered droppable nodes
        if (!droppable) return;
        // TODO modal support?
        if (!node.inBounds(outer, inner, pointerPosition).inSelf) return;

        // Make sure this slot can be dropped in
        if (!droppable.canDrop(slot)) return;

        this.target = droppable;
        this.targetRectangle = rectangle;

    }

    /// Tree drawn, draw the node now.
    override void afterTree() {

        if (slot.overlayIO is null ) {
            drawSlot(slot.tree.root);
        }

    }

    void drawSlot(Node parent) {

        const rect = slot.dragRectangle(offset);

        // Draw the slot
        slot.drawDragged(parent, rect);

    }

    /// Process input.
    override void afterInput(ref bool focusHandled) {

        // We should have received a signal from the slot if it is still being dragged
        if (!_stopDragging) {
            _stopDragging = true;
            if (target) {
                target.dropHover(pointerPosition, relativeDragRectangle);
            }
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
                slot.overlay.remove();
                _readyToDrop = true;
                return;
            }

        }

        // Stop dragging
        slot.dragAction = null;  // TODO Don't nullify this
        slot.overlay.remove();
        slot.updateSize();
        stop;

    }

}
