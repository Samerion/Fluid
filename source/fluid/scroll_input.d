module fluid.scroll_input;

import std.algorithm;

import fluid.node;
import fluid.utils;
import fluid.input;
import fluid.style;
import fluid.backend;


@safe:


deprecated("scrollBars have been renamed to scrollInputs, please update references before 0.7.0") {

    alias vscrollBar = vscrollInput;
    alias hscrollBar = hscrollInput;
    alias FluidScrollBar = FluidScrollInput;

}

/// Create a new vertical scroll bar.
alias vscrollInput = simpleConstructor!FluidScrollInput;

/// Create a new horizontal scroll bar.
alias hscrollInput = simpleConstructor!(FluidScrollInput, (a) {

    a.horizontal = true;

});

///
class FluidScrollInput : FluidInput!FluidNode {

    // TODO Hiding a scrollbar makes it completely unusable, since it cannot scan the viewport. Perhaps override
    // `isHidden` to virtually hide the scrollbar, and keep it always "visible" as such?

    /// Styles defined by this node:
    ///
    /// `backgroundStyle` — style defined for the background part of the scrollbar,
    ///
    /// `pressStyle` — style to activate while the scrollbar is pressed.
    mixin defineStyles!(
        "backgroundStyle", q{ Style.init },
        "pressStyle", q{ style },
    );

    mixin implHoveredRect;
    mixin enableInputActions;

    public {

        /// Mouse scroll speed; Pixels per mouse wheel event in FluidScrollable.
        enum scrollSpeed = 60.0;

        /// Keyboard/gamepad
        enum actionScrollSpeed = 1000.0;

        // TODO HiDPI should affect scrolling speed

        /// If true, the scrollbar will be horizontal.
        bool horizontal;

        /// Amount of pixels the page is scrolled down.
        size_t position;

        /// Available space to scroll.
        ///
        /// Note: visible box size, and therefore scrollbar handle length, are determined from the space occupied by the
        /// scrollbar.
        size_t availableSpace;

        /// Width of the scrollbar.
        size_t width = 10;

    }

    protected {

        /// True if the scrollbar is pressed.
        bool _isPressed;

        /// If true, the inner part of the scrollbar is hovered.
        bool innerHovered;

        /// Page length as determined in drawImpl.
        double pageLength;

        /// Length of the scrollbar as determined in drawImpl.
        double scrollbarLength;

        /// Length of the handle.
        double handleLength;

        /// Position of the scrollbar on the screen.
        Vector2 scrollbarPosition;

        /// Position where the mouse grabbed the scrollbar.
        Vector2 grabPosition;

        /// Start position of the mouse at the beginning of the grab.
        size_t startPosition;

    }

    this(Args...)(Args args) {

        super(args);

    }

    @property
    bool isPressed() const {

        return _isPressed;

    }

    /// Set the scroll to a value clamped between start and end. Doesn't trigger the `changed` event.
    void setScroll(ptrdiff_t value) {

        position = cast(size_t) value.clamp(0, scrollMax);

    }

    /// Ditto
    void setScroll(float value) {

        position = cast(size_t) value.clamp(0, scrollMax);

    }

    /// Get the maximum value this container can be scrolled to. Requires at least one draw.
    size_t scrollMax() const {

        return cast(size_t) max(0, availableSpace - pageLength);

    }

    /// Set the total size of the scrollbar. Will always fill the available space in the target direction.
    override protected void resizeImpl(Vector2 space) {

        // Get minSize
        minSize = horizontal
            ? Vector2(space.x, width)
            : Vector2(width, space.y);

        // Get the expected page length
        pageLength = horizontal
            ? space.x + style.padding.sideX[].sum + style.margin.sideX[].sum
            : space.y + style.padding.sideY[].sum + style.margin.sideY[].sum;

    }

    override protected void drawImpl(Rectangle paddingBox, Rectangle contentBox) @trusted {

        // Clamp the values first
        setScroll(position);

        // Draw the background
        backgroundStyle.drawBackground(tree.io, paddingBox);

        // Calculate the size of the scrollbar
        scrollbarPosition = Vector2(contentBox.x, contentBox.y);
        scrollbarLength = horizontal ? contentBox.width : contentBox.height;
        handleLength = availableSpace
            ? max(50, scrollbarLength^^2 / availableSpace)
            : 0;

        const handlePosition = (scrollbarLength - handleLength) * position / scrollMax;

        // Now get the size of the inner rect
        auto innerRect = contentBox;

        if (horizontal) {

            innerRect.x += handlePosition;
            innerRect.w  = handleLength;

        }

        else {

            innerRect.y += handlePosition;
            innerRect.h  = handleLength;

        }

        // Check if the inner part is hovered
        innerHovered = innerRect.contains(io.mousePosition);

        // Get the inner style
        const innerStyle = pickStyle();

        innerStyle.drawBackground(tree.io, innerRect);

    }

    override protected inout(Style) pickStyle() inout {

        auto up = super.pickStyle();

        // The outer part is being hovered...
        if (up is hoverStyle) {

            // Check if the inner part is
            return innerHovered
                ? hoverStyle
                : style;

        }

        return up;

    }

    override protected void mouseImpl() @trusted {

        // Ignore if we can't scroll
        if (availableSpace == 0) return;

        // Check if the button is held down
        const isDown = tree.isDown!(FluidInputAction.press);

        // Update status
        scope (exit) _isPressed = isDown;

        // Pressed the scrollbar just now
        if (isDown && !isPressed) {

            // Remember the grab position
            grabPosition = io.mousePosition;
            scope (exit) startPosition = position;

            // Didn't press the handle
            if (!innerHovered) {

                // Get the position
                const posdir = horizontal ? scrollbarPosition.x : scrollbarPosition.y;
                const grabdir = horizontal ? grabPosition.x : grabPosition.y;
                const screenPos = grabdir - posdir - handleLength/2;

                // Move it to this position
                setScroll(screenPos * availableSpace / scrollbarLength);

            }

        }

        // Handle is held down
        else if (isDown) {

            const mouse = io.mousePosition;

            const float move = horizontal
                ? mouse.x - grabPosition.x
                : mouse.y - grabPosition.y;

            // Move the scrollbar
            setScroll(startPosition + move * availableSpace / scrollbarLength);

        }

    }

    @(FluidInputAction.pageLeft, FluidInputAction.pageRight)
    @(FluidInputAction.pageUp, FluidInputAction.pageDown)
    protected void _scrollPage(FluidInputAction action) {

        with (FluidInputAction) {

            // Check if we're moving horizontally
            const forHorizontal = action == pageLeft || action == pageRight;

            // Check direction
            const direction = action == pageLeft || action == pageUp
                ? -1
                : 1;

            // Change
            if (horizontal ^ forHorizontal) emitChange(direction * scrollPageLength);

        }

    }

    @(FluidInputAction.scrollLeft, FluidInputAction.scrollRight)
    @(FluidInputAction.scrollUp, FluidInputAction.scrollDown)
    protected void _scroll() @trusted {

        const isPlus = horizontal
            ? &isDown!(FluidInputAction.scrollRight)
            : &isDown!(FluidInputAction.scrollDown);
        const isMinus = horizontal
            ? &isDown!(FluidInputAction.scrollLeft)
            : &isDown!(FluidInputAction.scrollUp);

        const speed = cast(ulong) (actionScrollSpeed * io.deltaTime);
        const change
            = isPlus(tree)  ? +speed
            : isMinus(tree) ? -speed
            : 0;

        emitChange(change);


    }

    /// Change the value and run the `changed` callback.
    protected void emitChange(ptrdiff_t move) {

        // Ignore if nothing changed.
        if (move == 0) return;

        // Update scroll
        setScroll(position + move);

        // Run the callback
        if (changed) changed();

    }

    /// Scroll page length used for `pageUp` and `pageDown` navigation.
    protected ulong scrollPageLength() const {

        return cast(ulong) (scrollbarLength * 3/4);

    }

}
