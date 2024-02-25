module fluid.scroll;

import std.meta;
import std.conv;
import std.algorithm;

import fluid.node;
import fluid.frame;
import fluid.space;
import fluid.utils;
import fluid.input;
import fluid.style;
import fluid.backend;
import fluid.structs;
import fluid.container;

public import fluid.scroll_input;


@safe:


alias ScrollFrame = Scrollable!Frame;
alias Scrollable(T : Space) = Scrollable!(T, "directionHorizontal");

/// Create a new vertical scroll frame.
alias vscrollFrame = simpleConstructor!ScrollFrame;

/// Create a new horizontal scroll frame.
alias hscrollFrame = simpleConstructor!(ScrollFrame, (a) {

    a.directionHorizontal = true;

});

/// Create a new scrollable node.
alias vscrollable(alias T) = simpleConstructor!(ApplyRight!(ScrollFrame, "false"), T);

/// Create a new horizontally scrollable node.
alias hscrollable(alias T) = simpleConstructor!(ApplyRight!(ScrollFrame, "true"), T);

/// Implement scrolling for the given node.
///
/// This only supports scrolling in one axis.
class Scrollable(T : Node, string horizontalExpression) : T, AnyScrollable {

    mixin DefineStyles;

    public {

        /// Scrollbar for the frame. Can be replaced with a customized one.
        ScrollInput scrollBar;

    }

    private {

        /// minSize including the padding.
        Vector2 paddingBoxSize;

    }

    this(T...)(T args) {

        super(args);
        this.scrollBar = .vscrollInput();

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

    /// Scroll to the given node.
    Rectangle shallowScrollTo(const Node, Vector2, Rectangle parentBox, Rectangle childBox) {

        struct Position {

            float* start;
            float end;
            float viewportStart, viewportEnd;

        }

        // Get the data for the node
        scope position = isHorizontal
            ? Position(
                &childBox.x, childBox.x + childBox.width,
                parentBox.x, parentBox.x + parentBox.width
            )
            : Position(
                &childBox.y, childBox.y + childBox.height,
                parentBox.y, parentBox.y + parentBox.height
            );

        auto scrollBefore = scroll();

        // Calculate the offset
        auto offset

            // Need to scroll towards the end
            = *position.start > position.viewportStart && position.end > position.viewportEnd
            ? to!ptrdiff_t(position.end - position.viewportEnd)

            // Need to scroll towards the start
            : *position.start < position.viewportStart && position.end < position.viewportEnd
            ? to!ptrdiff_t(*position.start - position.viewportStart)

            // Already in viewport
            : 0;

        // Perform the scroll
        setScroll(scroll.to!ptrdiff_t + offset);

        // Adjust the offset
        offset = scroll.to!ptrdiff_t - scrollBefore;

        // Apply child position
        *position.start -= offset;

        return childBox;

    }

    override void resizeImpl(Vector2 space) {

        assert(scrollBar !is null, "No scrollbar has been set for FluidScrollable");
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

        // This node doesn't use InputNode because it doesn't take focus, and we don't want to cause related
        // accessibility issues. It can function perfectly without it, or at least until above note gets fixed.
        // Then, a "FluidHoverable" interface could possibly become a thing.

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

        // TODO do this via input actions somehow https://git.samerion.com/Samerion/Fluid/issues/89
        const speed = scrollBar.scrollSpeed;
        const value = isHorizontal
            ? io.scroll.x
            : io.scroll.y;
        const move = speed * value;
        // io.deltaTime is irrelevant here

        // TODO NO ptrdiff_t
        scrollBar.setScroll(scroll.to!ptrdiff_t + move.to!ptrdiff_t);

    }

}

interface AnyScrollable {

    void setScroll(ptrdiff_t value);
    ref inout(size_t) scroll() inout;
    Rectangle shallowScrollTo(const Node, Vector2, Rectangle parentBox, Rectangle childBox);

}
