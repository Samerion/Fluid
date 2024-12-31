module fluid.scroll_input;

import std.math;
import std.algorithm;

import fluid.node;
import fluid.utils;
import fluid.input;
import fluid.style;
import fluid.backend;

import fluid.io.hover;
import fluid.io.canvas;


@safe:


/// Create a new vertical scroll bar.
alias vscrollInput = simpleConstructor!ScrollInput;

/// Create a new horizontal scroll bar.
alias hscrollInput = simpleConstructor!(ScrollInput, (a) {

    a.isHorizontal = true;

});

///
class ScrollInput : InputNode!Node {

    // TODO Hiding a scrollbar makes it completely unusable, since it cannot scan the viewport. Perhaps override
    // `isHidden` to virtually hide the scrollbar, and keep it always "visible" as such?

    mixin enableInputActions;

    CanvasIO canvasIO;

    public {

        /// Mouse scroll speed; Pixels per event in Scrollable.
        enum scrollSpeed = 60.0;

        /// Keyboard/gamepad scroll speed in pixels per event.
        enum actionScrollSpeed = 60.0;

        /// If true, the scrollbar will be horizontal.
        bool isHorizontal;

        alias horizontal = isHorizontal;

        /// Amount of pixels the page is scrolled down.
        float position = 0;

        /// Available space to scroll.
        ///
        /// Note: visible box size, and therefore scrollbar handle length, are determined from the space occupied by the
        /// scrollbar.
        float availableSpace = 0;

        /// Width of the scrollbar.
        float width = 10;

        /// Handle of the scrollbar.
        ScrollInputHandle handle;

    }

    protected {

        /// True if the scrollbar is pressed.
        bool _isPressed;

        /// If true, the inner part of the scrollbar is hovered.
        bool innerHovered;

        /// Page length as determined in resizeImpl.
        double pageLength;

        /// Length of the scrollbar as determined in drawImpl.
        double length;

    }

    this() {

        handle = new ScrollInputHandle(this);

    }

    bool isPressed() const {

        return _isPressed;

    }

    /// Scroll page length used for `pageUp` and `pageDown` navigation.
    float scrollPageLength() const {

        return length * 0.75;

    }

    /// Set the scroll to a value clamped between start and end. Doesn't trigger the `changed` event.
    void setScroll(float value) {

        assert(scrollMax.isFinite);

        position = value.clamp(0, scrollMax);

        assert(position.isFinite);

    }

    /// Get the maximum value this container can be scrolled to. Requires at least one draw.
    float scrollMax() const {

        return max(0, availableSpace - pageLength);

    }

    /// Set the total size of the scrollbar. Will always fill the available space in the target direction.
    override protected void resizeImpl(Vector2 space) {

        super.resizeImpl(space);
        use(canvasIO);

        // Get minSize
        minSize = isHorizontal
            ? Vector2(space.x, width)
            : Vector2(width, space.y);

        // Get the expected page length
        pageLength = isHorizontal
            ? space.x + style.padding.sideX[].sum + style.margin.sideX[].sum
            : space.y + style.padding.sideY[].sum + style.margin.sideY[].sum;

        // Resize the handle
        resizeChild(handle, minSize);

    }

    override protected void drawImpl(Rectangle paddingBox, Rectangle contentBox) @trusted {

        _isPressed = checkIsPressed;

        const style = pickStyle();

        // Clamp the values first
        setScroll(position);

        // Draw the background
        style.drawBackground(tree.io, canvasIO, paddingBox);

        // Ignore if we can't scroll
        if (scrollMax == 0) return;

        // Calculate the size of the scrollbar
        length = isHorizontal ? contentBox.width : contentBox.height;
        handle.length = availableSpace
            ? max(handle.minimumLength, length^^2 / availableSpace)
            : 0;

        const handlePosition = (length - handle.length) * position / scrollMax;

        // Now create a rectangle for the handle
        auto handleRect = contentBox;

        if (isHorizontal) {

            handleRect.x += handlePosition;
            handleRect.w  = handle.length;

        }

        else {

            handleRect.y += handlePosition;
            handleRect.h  = handle.length;

        }

        drawChild(handle, handleRect);

    }

    @(FluidInputAction.pageLeft, FluidInputAction.pageRight)
    @(FluidInputAction.pageUp, FluidInputAction.pageDown)
    protected void scrollPage(FluidInputAction action) {

        with (FluidInputAction) {

            // Check if we're moving horizontally
            const forHorizontal = action == pageLeft || action == pageRight;

            // Check direction
            const direction = action == pageLeft || action == pageUp
                ? -1
                : 1;

            // Change
            if (isHorizontal == forHorizontal) emitChange(direction * scrollPageLength);

        }

    }

    @(FluidInputAction.scrollLeft, FluidInputAction.scrollRight)
    @(FluidInputAction.scrollUp, FluidInputAction.scrollDown)
    protected void scroll(FluidInputAction action) @trusted {

        const isPlus = isHorizontal
            ? action == FluidInputAction.scrollRight
            : action == FluidInputAction.scrollDown;
        const isMinus = isHorizontal
            ? action == FluidInputAction.scrollLeft
            : action == FluidInputAction.scrollUp;

        const change
            = isPlus  ? +actionScrollSpeed
            : isMinus ? -actionScrollSpeed
            : 0;

        emitChange(change);


    }

    /// Change the value and run the `changed` callback.
    protected void emitChange(float move) {

        // Ignore if nothing changed.
        if (move == 0) return;

        // Update scroll
        setScroll(position + move);

        // Run the callback
        if (changed) changed();

    }

}

class ScrollInputHandle : Node, FluidHoverable, Hoverable {

    mixin makeHoverable;
    mixin FluidHoverable.enableInputActions;
    mixin Hoverable.enableInputActions;

    HoverIO hoverIO;

    public {

        enum minimumLength = 50;

        ScrollInput parent;

    }

    protected {

        /// Length of the handle.
        double length;

        /// True if the handle was pressed this frame.
        bool justPressed;

        /// Position of the mouse when dragging started.
        Vector2 startMousePosition;

        /// Scroll value when dragging started.
        float startScrollPosition;

    }

    private {

        bool _isPressed;

    }

    this(ScrollInput parent) {

        import fluid.structs : layout;

        this.layout = layout!"fill";
        this.parent = parent;

    }

    bool isPressed() const {

        return _isPressed;

    }

    bool isFocused() const {

        return parent.isFocused;

    }

    override bool blocksInput() const {

        return isDisabled || isDisabledInherited;

    }

    override bool isHovered() const {

        return this is tree.hover || super.isHovered();

    }

    override protected void resizeImpl(Vector2 space) {

        use(hoverIO);

        if (parent.isHorizontal)
            minSize = Vector2(minimumLength, parent.width);
        else
            minSize = Vector2(parent.width, minimumLength);

    }

    override protected void drawImpl(Rectangle paddingBox, Rectangle contentBox) @trusted {

        auto style = pickStyle();
        style.drawBackground(io, paddingBox);

    }

    @(FluidInputAction.press, fluid.input.WhileDown)
    protected bool whileDown(Pointer pointer) @trusted {

        const mousePosition = pointer.position;

        assert(startMousePosition.x.isFinite);
        assert(startMousePosition.y.isFinite);

        justPressed = !_isPressed;
        _isPressed = true;

        // Just pressed, save data
        if (justPressed) {

            startMousePosition = mousePosition;
            startScrollPosition = parent.position;
            return true;

        }

        const totalMove = parent.isHorizontal
            ? mousePosition.x - startMousePosition.x
            : mousePosition.y - startMousePosition.y;

        const scrollDifference = totalMove * parent.scrollMax / (parent.length - length);

        assert(totalMove.isFinite);
        assert(parent.length.isFinite);
        assert(length.isFinite);
        assert(startScrollPosition.isFinite);
        assert(scrollDifference.isFinite);

        // Move the scrollbar
        parent.setScroll(startScrollPosition + scrollDifference);

        // Emit signal
        if (parent.changed) parent.changed();

        return true;

    }

    @(FluidInputAction.press, fluid.input.WhileDown)
    protected void whileDown() @trusted {

        // Call the new overload if new I/O isn't loaded
        if (hoverIO is null) {
            Pointer pointer;
            pointer.position = io.mousePosition;
            cast(void) whileDown(pointer);
        }

    }

    protected override void mouseImpl() {

        hoverImpl();

    }

    protected override bool hoverImpl() {

        justPressed = false;
        _isPressed = false;

        return false;

    }

}
