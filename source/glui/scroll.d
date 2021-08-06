module glui.scroll;

import raylib;

import std.conv;
import std.algorithm;

import glui.node;
import glui.frame;
import glui.space;
import glui.utils;
import glui.input;

private extern(C) float GetMouseWheelMove();

alias scrollFrame = simpleConstructor!(GluiScrollable!GluiFrame);

/// Implement scrolling for the given frame.
///
/// This only supports scrolling in one side.
class GluiScrollable(T : GluiFrame) : GluiInput!T {

    /// Multipler of the scroll speed.
    enum scrollSpeed = 15.0;

    /// Actual size of the node, determined by drawImpl.
    private size_t actualSize;

    /// Amount of pixels the node is scrolled in the space direction.
    size_t scroll;

    this(T...)(T args) {

        super(args);

    }

    override void drawImpl(Rectangle rect) {

        // Note: mouse input detection is primitive, awaiting #13 and #14 to help better identify when should the mouse
        // affect this frame.

        // Scroll the given rectangle horizontally
        if (directionHorizontal) {

            actualSize = cast(size_t) rect.x;

            if (hovered) inputImpl();

            rect.x -= scroll;
            rect.w = minSize.x;

        }

        // Vertically
        else {

            actualSize = cast(size_t) rect.y;

            if (hovered) inputImpl();

            rect.y -= scroll;
            rect.h = minSize.y;

        }

        super.drawImpl(rect);

    }

    /// Actual implementation of mouse input
    private void inputImpl() {

        const float move = -GetMouseWheelMove;
        const float totalChange = move * scrollSpeed;

        setScroll(scroll.to!ptrdiff_t + totalChange.to!ptrdiff_t);

    }

    override protected void mouseImpl() {

        // We're scrolling on draw because a child might've caught the input
        // For now we just focus
        focus();

    }

    override protected bool keyboardImpl() {

        const arrowSpeed = scrollSpeed / 3.0;
        const pageSpeed = actualSize.to!double * 3/4;

        const move = IsKeyPressed(KeyboardKey.KEY_PAGE_DOWN) ? +pageSpeed
            : IsKeyPressed(KeyboardKey.KEY_PAGE_UP) ? -pageSpeed
            : IsKeyDown(KeyboardKey.KEY_DOWN) ? +arrowSpeed
            : IsKeyDown(KeyboardKey.KEY_UP) ? -arrowSpeed
            : 0;

        setScroll(scroll.to!ptrdiff_t + move.to!ptrdiff_t);

        return move != 0;

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

        scroll = clamp(value, 0, scrollMax);

    }

    /// Get the maximum value this container can be scrolled to. Requires at least one draw.
    size_t scrollMax() const {

        const fullSize = directionHorizontal ? minSize.x : minSize.y;

        return max(0, fullSize.to!ptrdiff_t - actualSize.to!ptrdiff_t).to!size_t;

    }

}
