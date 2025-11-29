/// [ScrollFrame] is a container node that can be "scrolled" to display content that
/// can't normally fit in view. It extends from [Frame] and otherwise acts like one.
///
/// `ScrollFrame` can be created using either [vscrollFrame] to create a vertical frame (column)
/// or [hscrollFrame] to create a horizontal frame (row).
///
/// Contents can be scrolled using mouse wheel or the included scroll bar (see
/// [ScrollFrame.scrollBar]). Keyboard users may be able to tab into the scrollbar and use arrow,
/// page up, and page down keys to scroll.
///
/// You can use [fluid.actions.scrollToTop] or [fluid.actions.scrollIntoView] to move child nodes
/// into view by calculating the right offsets. The two functions work even if multiple scroll
/// frames (and other scrollable nodes) are nested.
module fluid.scroll_frame;

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

import fluid.io.hover;

public import fluid.scroll_input;


@safe:


/// Create a new vertical scroll frame.
alias vscrollFrame = simpleConstructor!ScrollFrame;

/// Create a new horizontal scroll frame.
alias hscrollFrame = simpleConstructor!(ScrollFrame, (a) {
    a.directionHorizontal = true;
});

/// Implement scrolling for the given node.
///
/// This node only supports scrolling in one axis.
class ScrollFrame : Frame, FluidScrollable, HoverScrollable {

    HoverIO hoverIO;

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
        this.scrollBar = .vscrollInput(.layout!(1, "fill"));

    }

    alias opEquals = Node.opEquals;
    override bool opEquals(const Object other) const {
        return super.opEquals(other);
    }

    /// Distance the node is scrolled by.
    ref inout(float) scroll() inout {
        return scrollBar.position;
    }

    float scroll() const {
        return scrollBar.position;
    }

    float scroll(float value) {
        scrollBar.scroll = value;
        return value;
    }

    deprecated("`scrollStart` was renamed to `scrollToStart` and will be removed in Fluid 0.8.0")
    alias scrollStart = scrollToStart;

    deprecated("`scrollEnd` was renamed to `scrollToEnd` and will be removed in Fluid 0.8.0")
    alias scrollEnd = scrollToEnd;

    deprecated("`scrollMax` was renamed to `maxScroll` and will be removed in Fluid 0.8.0")
    alias scrollMax = maxScroll;

    /// Scroll to the beginning of the node.
    void scrollToStart() {
        scroll = 0;
    }

    /// Scroll to the end of the node, requires the node to be drawn at least once.
    void scrollToEnd() {
        scroll = maxScroll;
    }

    /// Set the scroll to a value clamped between start and end.
    deprecated("Instead of `setScroll(value)` use `scroll = value`. `setScroll` will be removed "
        ~ "in Fluid 0.8.0")
    void setScroll(float value) {
        scrollBar.setScroll(value);
    }

    /// Get the maximum value this container can be scrolled to. Requires at least one draw.
    float maxScroll() const {
        return scrollBar.maxScroll();
    }

    deprecated("shallowScrollTo with a Vector2 argument has been deprecated and will be removed "
        ~ "in Fluid 0.8.0.")
    Rectangle shallowScrollTo(const Node child, Vector2, Rectangle parentBox, Rectangle childBox) {
        return shallowScrollTo(child, parentBox, childBox);
    }

    /// Scroll to the given node.
    Rectangle shallowScrollTo(const Node, Rectangle parentBox, Rectangle childBox) {

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
            ? position.end - position.viewportEnd

            // Need to scroll towards the start
            : *position.start < position.viewportStart && position.end < position.viewportEnd
            ? *position.start - position.viewportStart

            // Already in viewport
            : 0;

        // Perform the scroll
        this.scroll = scroll + offset;

        // Adjust the offset
        offset = scroll - scrollBefore;

        // Apply child position
        *position.start -= offset;

        return childBox;

    }

    override void resizeImpl(Vector2 space) {

        assert(scrollBar !is null, "No scrollbar has been set for FluidScrollable");
        assert(tree !is null);

        use(hoverIO);

        /// Padding represented as a vector. This sums the padding on each axis.
        const paddingVector = Vector2(style.padding.sideX[].sum, style.padding.sideY[].sum);

        /// Space with padding included
        const paddingSpace = space + paddingVector;

        // Resize the scrollbar
        scrollBar.isHorizontal = this.isHorizontal;
        resizeChild(scrollBar, paddingSpace);

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

            scrollBar.availableSpace = paddingBoxSize.x;
            minSize.y += scrollBar.minSize.y;

        }

        else {

            scrollBar.availableSpace = paddingBoxSize.y;
            minSize.x += scrollBar.minSize.x;

        }

    }

    override void drawImpl(Rectangle mainOuter, Rectangle inner) {

        auto outer = mainOuter;
        auto scrollBarRect = outer;

        scrollBar.horizontal = isHorizontal;

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
            mainOuter.height -= scrollBarRect.height;

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
            mainOuter.width -= scrollBarRect.width;

        }

        // Draw the scrollbar
        drawChild(scrollBar, scrollBarRect);

        // Draw the frame
        if (canvasIO) {
            const lastArea = canvasIO.intersectCrop(mainOuter);
            scope (exit) canvasIO.cropArea = lastArea;
            super.drawImpl(mainOuter, inner);
        }
        else {
            super.drawImpl(mainOuter, inner);
        }

    }

    bool canScroll(Vector2 valueVec) const {
        const speed = scrollBar.scrollSpeed;
        const value = isHorizontal
            ? valueVec.x
            : valueVec.y;
        const move = speed * value;
        const maxMoveBackward = -scroll;
        const maxMoveForward  = maxScroll - scroll;

        return move.clamp(maxMoveBackward, maxMoveForward) != 0;
    }

    void scrollImpl(Vector2 valueVec) {
        const speed = scrollBar.scrollSpeed;
        const value = isHorizontal
            ? valueVec.x
            : valueVec.y;
        const move = speed * value;
        // io.deltaTime is irrelevant here

        this.scroll = scroll + move;
    }

    bool canScroll(const HoverPointer pointer) const {
        const value = isHorizontal
            ? pointer.scroll.x
            : pointer.scroll.y;
        const maxMoveBackward = -scroll;
        const maxMoveForward  = maxScroll - scroll;

        return value.clamp(maxMoveBackward, maxMoveForward) != 0;
    }

    bool scrollImpl(HoverPointer pointer) {
        const value = isHorizontal
            ? pointer.scroll.x
            : pointer.scroll.y;
        this.scroll = scroll + value;
        return true;
    }

}
