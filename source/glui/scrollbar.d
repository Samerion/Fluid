module glui.scrollbar;

import raylib;

import std.algorithm;

import glui.node;
import glui.utils;
import glui.input;
import glui.style;

alias vscrollBar = simpleConstructor!GluiScrollBar;

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

    }

    this(Args...)(Args args) {

        super(args);

    }

    /// Set the scroll to a value clamped between start and end.
    void setScroll(ptrdiff_t value) {

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

    override protected void drawImpl(Rectangle rect) {

        // Draw the background
        backgroundStyle.drawBackground(rect);

        // Calculate the size of the scrollbar
        scrollbarLength = horizontal ? rect.width : rect.height;

        const size = availableSpace
            ? max(50, scrollbarLength^^2 / availableSpace)
            : 0;
        const handlePosition = (scrollbarLength - size) * position / scrollMax;

        // Now get the size of the inner rect
        auto innerRect = rect;

        if (horizontal) {

            innerRect.x += handlePosition;
            innerRect.w  = size;

        }

        else {

            innerRect.y += handlePosition;
            innerRect.h  = size;

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
        if (up == hoverStyle) {

            // Check if the inner part is
            return innerHovered
                ? hoverStyle
                : style;

        }

        return up;

    }

    override protected void mouseImpl() {

    }

    override protected bool keyboardImpl() {

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

            setScroll(cast(long) (position + move));

            if (changed) changed();

            return true;

        }

        return false;

    }

}
