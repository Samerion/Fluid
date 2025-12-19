/// [DragSlot] is a node that can be dragged by the user, and then dropped into another location
/// in the node tree.
///
/// It can be constructed using [dragSlot] node builder.
module fluid.drag_slot;

@safe:

///
@("DragSlot usage example")
unittest {
    import fluid;

    vframe(
        .layout!"fill",
        vframe(
            .acceptDrop,
            .layout!(1, "fill"),
            dragSlot(
                label("Drag me!"),
            ),
        ),
        vframe(
            .acceptDrop,
            .layout!(1, "fill"),
        ),
    );
}

import std.array;
import std.range;

import fluid.tree;
import fluid.node;
import fluid.slot;
import fluid.input;
import fluid.utils;
import fluid.style;
import fluid.structs;
import fluid.frame : acceptDrop;

import fluid.io.hover;
import fluid.io.canvas;
import fluid.io.overlay;

import fluid.future.context;

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
class DragSlot : NodeSlot!Node, Hoverable {

    mixin Hoverable.enableInputActions;

    HoverIO hoverIO;
    OverlayIO overlayIO;

    public {

        /// An instance of [DragHandle] to indicate to the user that the node is draggable;
        /// the handle also provides safe space for the user to drag the node.
        DragHandle handle;

        /// In many cases the handle is not desirable, but it can be hidden or replaced.
        @("Hiding DragHandle")
        unittest {
            auto slot = dragSlot();
            slot.handle.hide();
        }

        /// [DragAction] is a [tree action][TreeAction] that controls the node while it is being
        /// dragged.
        ///
        /// The action is set to `null` while the slot is idle, and created whenever the slot
        /// it being dragged.
        DragAction dragAction;

        /// If used with [OverlayIO], a wrapper node is used to distinguish between the node's
        /// original parent, and the overlay.
        ///
        /// The overlay is created with the slot.
        ///
        /// See [DragSlotOverlay] for details.
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
    /// Params:
    ///     node = Node to place in the slot; optional, can be null.
    this(Node node = null) {
        super(node);
        this.handle = dragHandle(.layout!"fill");
        this.overlay = new DragSlotOverlay(this);
    }

    /// Returns:
    ///     If true, this node is currently being dragged.
    ///     This is equivalent to a null check on [dragAction].
    bool isDragged() const {
        return dragAction !is null;
    }

    /// Input event handler for hover input, activated every frame while the node
    /// is grabbed/dragged.
    ///
    /// Activated on [FluidInputAction.press] events in [WhileDown] mode.
    ///
    /// Params:
    ///     pointer = (New I/O only) Pointer performing the drag motion.
    @(FluidInputAction.press, .WhileDown)
    void drag(HoverPointer pointer)
    in (treeContext)
    do {

        // Ignore if already dragging
        if (dragAction) {
            dragAction._stopDragging = false;
            dragAction.pointerPosition = pointer.position;
        }

        // Queue the drag action
        else {
            dragAction = new DragAction(this, pointer.position);
            overlayIO.addOverlay(overlay, OverlayIO.types.draggable);
            auto hover = cast(Node) hoverIO;
            hover.startAction(dragAction);
            updateSize();
        }

    }

    alias isHidden = typeof(super).isHidden;

    /// `DragSlot` hides itself from its parent node while its drawn.
    /// Returns:
    ///     True while the drag slot is set to hidden or while its being dragged.
    override bool isHidden() const scope {

        // Don't hide from the draw action
        if (_drawDragged)
            return super.isHidden;

        // Hide the node from its parent if it's dragged
        else return super.isHidden || isDragged;

    }

    override bool blocksInput() const {
        return isDisabled;
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

    override void resizeImpl(Vector2 available) {
        require(hoverIO);
        require(overlayIO);

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

        // Draw the value
        super.drawImpl(outer, valueRect);

        // Draw the handle
        drawChild(handle, handleRect);
    }

    protected override bool hoveredImpl(Rectangle rect, Vector2 position) {
        return Node.hoveredImpl(rect, position);
    }

    override bool isHovered() const {
        return super.isHovered();
    }

    override bool hoverImpl(HoverPointer) {
        return false;
    }

    override bool opEquals(const Object other) const {
        return super.opEquals(other);
    }

}

/// Wraps [DragSlot] while the slot is being dragged. It implements [Overlayable] so it can be
/// used by [OverlayIO].
///
/// While dragged, the slot remains seated inside the same parent it was in, except
/// hidden to the parent. The `DragSlotOverlay` node provides a mechanism for the slot to
/// distinguish between its original parent, and the `OverlayIO` node.
///
/// **`DragSlotOverlay` does not offer a stable interface.** It may only be a temporary solution
/// for the detection problem, before a more general option is added for `OverlayIO`.
class DragSlotOverlay : Node, Overlayable {

    /// [DragSlot] the overlay is associated with.
    DragSlot next;

    /// Constructor for the wrapper.
    /// Params:
    ///     next = Drag slot node wrapped by the overlay.
    this(DragSlot next) {
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

    override bool opEquals(const Object other) const {
        return super.opEquals(other);
    }

}

/// Node builder for [DragHandle].
alias dragHandle = nodeBuilder!DragHandle;

/// `DragHandle` takes no constructor arguments, but its [layout] should usually be set to
/// [fill][NodeAlign.fill] mode.
unittest {
    dragHandle(
        .layout!"fill",
    );
}

/// Node to act as a visual cue that it can be dragged.
///
/// The handle is displayed as a bar with rounded ends. The color for the bar can be set using
/// [Style.lineColor].
class DragHandle : Node {

    CanvasIO canvasIO;

    /// Provides additional styling features for the Handle.
    static class Extra : typeof(super).Extra {

        /// Width of the `DragHandle`'s bar
        float width;

        /// Params:
        ///     width = Specify the bar's width.
        this(float width) {
            this.width = width;
        }

    }

    ///
    @("DragHandle theming example")
    unittest {
        import fluid.theme;

        // Use a 6 pixel wide faded teal bar
        auto myTheme = Theme(
            rule!DragHandle(
                lineColor = color("#6b8577"),
                extra = new DragHandle.Extra(6),
            ),
        );
    }

    /// Returns:
    ///     Width of the bar to use.
    ///     If [Extra] is provided in the theme, loads the width it has specified.
    ///     Otherwise, defaults to zero.
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
        require(canvasIO);
        minSize = Vector2(width * 2, width);
    }

    override void drawImpl(Rectangle outer, Rectangle inner) {
        const width = this.width;

        const radius = width / 2f;
        const circleVec = Vector2(radius, radius);
        const color = style.lineColor;
        const fill = style.cropBox(inner, [radius, radius, 0, 0]);

        canvasIO.drawCircle(start(inner) + circleVec, radius, color);
        canvasIO.drawCircle(end(inner) - circleVec, radius, color);
        canvasIO.drawRectangle(fill, color);
    }

}

/// This [TreeAction] controls [DragSlot] while it is dragged. It is automatically created
/// whenever a dragging motion starts. It applies both to legacy backend and new I/O.
class DragAction : TreeAction {

    public {

        /// [DragSlot] controlled by the action. Set only at the start of the motion.
        DragSlot slot;

        /// [HoverPointer][HoverPointer] position at the start of the motion. Set only at the
        /// start of the motion.
        Vector2 mouseStart;

        /// Currently hovered [FluidDroppable] drop target. Cleared
        /// in [beforeTree][TreeAction.beforeTree] and updated in
        /// [beforeDraw][TreeAction.beforeDraw].
        FluidDroppable target;

        /// Available space box of [target].
        Rectangle targetRectangle;

        /// Current position of the hover pointer performing the action.
        Vector2 pointerPosition;

    }

    private {

        bool _stopDragging;
        bool _readyToDrop;

    }

    /// Params:
    ///     slot            = Slot moved by this action.
    ///     pointerPosition = Initial position of the pointer controlling the node.
    this(DragSlot slot, Vector2 pointerPosition) {
        this.slot = slot;
        this.pointerPosition = pointerPosition;
        this.mouseStart = pointerPosition;
    }

    /// Returns:
    ///     Mouse offset; difference between [pointerPosition] and [mouseStart].
    Vector2 offset() const {
        return pointerPosition - mouseStart;
    }

    private Rectangle relativeDragRectangle() {
        const rect = slot.dragRectangle(offset);

        return Rectangle(
            (rect.start - targetRectangle.start).tupleof,
            rect.size.tupleof,
        );
    }

    override void beforeTree(Node, Rectangle) {
        target = null;
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

    override void afterTree() {

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

    private void drawSlot(Node parent) {
        const rect = slot.dragRectangle(offset);
        slot.drawDragged(parent, rect);
    }

}
