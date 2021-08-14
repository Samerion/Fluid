module glui.scroll;

import raylib;

import std.conv;
import std.algorithm;

import glui.node;
import glui.frame;
import glui.space;
import glui.utils;
import glui.input;
import glui.style;
import glui.scrollbar;

private extern(C) float GetMouseWheelMove();

alias GluiScrollFrame = GluiScrollable!GluiFrame;
alias vscrollFrame = simpleConstructor!GluiScrollFrame;

@safe:

GluiScrollFrame hscrollFrame(Args...)(Args args) {

    auto scroll = vscrollFrame(args);
    scroll.directionHorizontal = true;
    return scroll;

}

/// Implement scrolling for the given frame.
///
/// This only supports scrolling in one side.
class GluiScrollable(T : GluiFrame) : T {

    mixin DefineStyles;

    // TODO: move keyboard input to GluiScrollBar.

    public {

        /// Scrollbar for the frame. Can be replaced with a customzed one.
        GluiScrollBar scrollBar;

    }

    private {

        /// Actual size of the node, determined by drawImpl.
        size_t actualSize;

    }

    this(T...)(T args) {

        super(args);
        this.scrollBar = .vscrollBar();

    }

    @property {

        size_t scroll() const {

            return scrollBar.position;

        }

        size_t scroll(size_t value) {

            return scrollBar.position = value;

        }

    }

    /// Scroll to the beginning of the node.
    void scrollStart() {

        scroll = 0;

    }

    /// Scroll to the end of the node, requires the node to be drawn at least once.
    void scrollEnd() {

        scroll = scrollMax;

    }

    /// Set the scroll to a value clamped between start and end.
    void setScroll(ptrdiff_t value) {

        scrollBar.setScroll(value);

    }

    /// Get the maximum value this container can be scrolled to. Requires at least one draw.
    size_t scrollMax() const {

        return scrollBar.scrollMax();

    }

    override void resizeImpl(Vector2 space) {

        assert(scrollBar !is null);
        assert(theme !is null);
        assert(tree !is null);

        // Resize the scrollbar
        scrollBar.tree = tree;
        scrollBar.theme = theme;
        scrollBar.resize(space);

        // Update available space
        space.x = max(0, space.x - scrollBar.minSize.x);
        space.y = max(0, space.y - scrollBar.minSize.y);

        // Get the size
        super.resizeImpl(space);

        if (directionHorizontal) {

            scrollBar.availableSpace = cast(size_t) minSize.x;
            minSize.y += scrollBar.minSize.y;

        }

        else {

            scrollBar.availableSpace = cast(size_t) minSize.y;
            minSize.x += scrollBar.minSize.x;

        }

    }

    override void drawImpl(Rectangle rect) {

        // Note: Mouse input detection is primitive, awaiting #13 and #14 to help better identify when should the mouse
        // affect this frame.

        // This node doesn't use GluiInput because it doesn't take focus, and we don't want to cause related
        // accessibility issues. It can function perfectly without it, or at least until above note gets fixed.
        // Then, a "GluiHoverable" interface could possibly become a thing.

        scrollBar.horizontal = directionHorizontal;

        auto scrollBarRect = rect;

        // Scroll the given rectangle horizontally
        if (directionHorizontal) {

            actualSize = cast(size_t) rect.x;

            if (hovered) inputImpl();

            rect.x -= scroll;
            rect.width = minSize.x;
            rect.height -= scrollBar.minSize.y;

            scrollBarRect.y += rect.height;
            scrollBarRect.height = scrollBar.minSize.y;

        }

        // Vertically
        else {

            actualSize = cast(size_t) rect.y;

            if (hovered) inputImpl();

            rect.y -= scroll;
            rect.width -= scrollBar.minSize.x;
            rect.height = minSize.y;

            scrollBarRect.x += rect.width;
            scrollBarRect.width = scrollBar.minSize.x;

        }

        // Draw the scrollbar
        scrollBar.draw(scrollBarRect);

        // Draw the frame
        super.drawImpl(rect);

    }

    /// Implementation of mouse input
    private void inputImpl() @trusted {

        const float move = -GetMouseWheelMove;
        const float totalChange = move * scrollBar.scrollSpeed;

        scrollBar.setScroll(scroll.to!ptrdiff_t + totalChange.to!ptrdiff_t);

    }

}
