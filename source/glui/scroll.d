module glui.scroll;

import raylib;

import std.meta;
import std.conv;
import std.algorithm;

import glui.node;
import glui.frame;
import glui.space;
import glui.utils;
import glui.input;
import glui.style;
import glui.structs;

public import glui.scrollbar;

private extern(C) float GetMouseWheelMove();


@safe:


alias GluiScrollFrame = GluiScrollable!GluiFrame;
alias GluiScrollable(T : GluiSpace) = GluiScrollable!(T, "directionHorizontal");

/// Create a new vertical scroll frame.
alias vscrollFrame = simpleConstructor!GluiScrollFrame;

/// Create a new horizontal scroll frame.
alias hscrollFrame = simpleConstructor!(GluiScrollFrame, (a) {

    a.directionHorizontal = true;

});

/// Implement scrolling for the given node.
///
/// This only supports scrolling in one axis.
class GluiScrollable(T : GluiNode, string horizontalExpression) : T {

    mixin DefineStyles;

    // TODO: move keyboard input to GluiScrollBar.

    public {

        /// Scrollbar for the frame. Can be replaced with a customized one.
        GluiScrollBar scrollBar;

    }

    private {

        /// minSize including the padding.
        Vector2 paddingBoxSize;

    }

    this(T...)(T args) {

        super(args);
        this.scrollBar = .vscrollBar();

    }

    /// Distance the node is scrolled by.
    @property
    ref inout(size_t) scroll() inout { return scrollBar.position; }

    /// Check if the underlying node is horizontal.
    private bool isHorizontal() const {

        return mixin(horizontalExpression);

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

        assert(scrollBar !is null, "No scrollbar has been set for GluiScrollable");
        assert(theme !is null);
        assert(tree !is null);

        /// Padding represented as a vector. This sums the padding on each axis.
        const paddingVector = Vector2(style.padding.sideX[].sum, style.padding.sideY[].sum);

        /// Space with padding included
        const paddingSpace = space + paddingVector;

        // Resize the scrollbar
        with (scrollBar) {

            horizontal = isHorizontal;
            layout = .layout!(1, "fill");
            resize(this.tree, this.theme, paddingSpace);

        }

        /// Space without the scrollbar
        const contentSpace = isHorizontal
            ? space - Vector2(0, scrollBar.minSize.y)
            : space - Vector2(scrollBar.minSize.x, 0);

        // Resize the frame while reserving some space for the scrollbar
        super.resizeImpl(contentSpace);

        // Calculate the expected padding box size
        paddingBoxSize = minSize + paddingVector;

        // Set scrollbar size and add the scrollbar to the result
        if (isHorizontal) {

            scrollBar.availableSpace = cast(size_t) paddingBoxSize.x;
            minSize.y += scrollBar.minSize.y;

        }

        else {

            scrollBar.availableSpace = cast(size_t) paddingBoxSize.y;
            minSize.x += scrollBar.minSize.x;

        }

    }

    override void drawImpl(Rectangle outer, Rectangle inner) {

        // Note: Mouse input detection is primitive, awaiting #13 and #14 to help better identify when should the mouse
        // affect this frame.

        // This node doesn't use GluiInput because it doesn't take focus, and we don't want to cause related
        // accessibility issues. It can function perfectly without it, or at least until above note gets fixed.
        // Then, a "GluiHoverable" interface could possibly become a thing.

        // TODO Is the above still true?

        scrollBar.horizontal = isHorizontal;

        auto scrollBarRect = outer;

        if (isHovered) inputImpl();

        // Scroll the given rectangle horizontally
        if (isHorizontal) {

            // Calculate fake box sizes
            outer.width = max(outer.width, paddingBoxSize.x);
            inner = style.contentBox(outer);

            static foreach (rect; AliasSeq!(outer, inner)) {

                // Perform the scroll
                rect.x -= scroll;

                // Reduce both rects by scrollbar size
                rect.height -= scrollBar.minSize.y;

            }

            scrollBarRect.y += outer.height;
            scrollBarRect.height = scrollBar.minSize.y;

        }

        // Vertically
        else {

            // Calculate fake box sizes
            outer.height = max(outer.height, paddingBoxSize.y);
            inner = style.contentBox(outer);

            static foreach (rect; AliasSeq!(outer, inner)) {

                // Perform the scroll
                rect.y -= scroll;

                // Reduce both rects by scrollbar size
                rect.width -= scrollBar.minSize.x;

            }

            scrollBarRect.x += outer.width;
            scrollBarRect.width = scrollBar.minSize.x;

        }

        // Draw the scrollbar
        scrollBar.draw(scrollBarRect);

        // Draw the frame
        super.drawImpl(outer, inner);

    }

    /// Implementation of mouse input
    private void inputImpl() @trusted {

        // Ignore if horizontal (For now; TODO)
        if (isHorizontal) return;

        const float move = -GetMouseWheelMove;
        const float totalChange = move * scrollBar.scrollSpeed;

        scrollBar.setScroll(scroll.to!ptrdiff_t + totalChange.to!ptrdiff_t);

    }

}
