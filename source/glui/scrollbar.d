module glui.scrollbar;

import raylib;

import std.algorithm;

import glui.node;
import glui.utils;
import glui.input;
import glui.style;

alias vscrollBar = simpleConstructor!GluiScrollBar;

@safe:

GluiScrollBar hscrollBar(Args...)(Args args) {

    auto bar = vscrollBar(args);
    bar.horizontal = true;
    return bar;

}

///
class GluiScrollBar : GluiInput!GluiNode {

    /// Styles defined by this node:
    ///
    /// `backgroundStyle` — style defined for the background part of the scrollbar,
    ///
    /// `pressStyle` — style to activate while the scrollbar is pressed.
    mixin DefineStyles!(
        "backgroundStyle", q{ Style.init },
        "pressStyle", q{ style },
    );

    mixin ImplHoveredRect;

    public {

        /// If true, the scrollbar will be horizontal.
        bool horizontal;

        /// Amount of pixel the page is scrolled down.
        size_t position;

        /// Available space to scroll.
        ///
        /// Note: page length, and therefore scrollbar handle length, are determined from the space occupied by the
        /// scrollbar.
        size_t availableSpace;

        /// Multipler of the scroll speed; applies to keyboard scroll only.
        ///
        /// This is actually number of pixels per mouse wheel event, as `GluiScrollable` determines mouse scroll speed
        /// based on this.
        enum scrollSpeed = 15.0;

    }

    protected {

        /// If true, the inner part of the scrollbar is hovered.
        bool innerHovered;

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

    /// Set the scroll to a value clamped between start and end.
    void setScroll(ptrdiff_t value) {

        position = cast(size_t) value.clamp(0, scrollMax);

    }

    /// Ditto
    void setScroll(float value) {

        position = cast(size_t) value.clamp(0, scrollMax);

    }

    /// Get the maximum value this container can be scrolled to. Requires at least one draw.
    size_t scrollMax() const {

        return cast(size_t) max(0, availableSpace - scrollbarLength);

    }

    /// Set the total size of the scrollbar. Will always fill the available space in the target direction.
    override protected void resizeImpl(Vector2 space) {

        minSize = horizontal
            ? Vector2(space.x, 10)
            : Vector2(10, space.y);

    }

    override protected void drawImpl(Rectangle paddingBox, Rectangle contentBox) @trusted {

        setScroll(position);

        // Draw the background
        backgroundStyle.drawBackground(paddingBox);

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
        innerHovered = innerRect.contains(GetMousePosition);

        // Get the inner style
        const innerStyle = pickStyle();

        innerStyle.drawBackground(innerRect);

    }

    override protected const(Style) pickStyle() const {

        const up = super.pickStyle();

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

        const triggerButton = MouseButton.MOUSE_LEFT_BUTTON;

        // Ignore if we can't scroll
        if (availableSpace == 0) return;

        // Pressed the scrollbar
        if (IsMouseButtonPressed(triggerButton)) {

            // Remember the grab position
            grabPosition = GetMousePosition;
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

        // Mouse is held down
        else if (IsMouseButtonDown(triggerButton)) {

            const mouse = GetMousePosition;

            const float move = horizontal
                ? mouse.x - grabPosition.x
                : mouse.y - grabPosition.y;

            // Move the scrollbar
            setScroll(startPosition + move * availableSpace / scrollbarLength);

        }

    }

    override protected bool keyboardImpl() @trusted {

        const plusKey = horizontal
            ? KeyboardKey.KEY_RIGHT
            : KeyboardKey.KEY_DOWN;
        const minusKey = horizontal
            ? KeyboardKey.KEY_LEFT
            : KeyboardKey.KEY_UP;

        const arrowSpeed = scrollSpeed * 20 * GetFrameTime;
        const pageSpeed = scrollbarLength * 3/4;

        const move = IsKeyPressed(KeyboardKey.KEY_PAGE_DOWN) ? +pageSpeed
            : IsKeyPressed(KeyboardKey.KEY_PAGE_UP) ? -pageSpeed
            : IsKeyDown(plusKey) ? +arrowSpeed
            : IsKeyDown(minusKey) ? -arrowSpeed
            : 0;

        if (move != 0) {

            setScroll(position + move);

            if (changed) changed();

            return true;

        }

        return false;

    }

}
