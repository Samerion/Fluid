module fluid.slider;

import std.range;

import fluid.node;
import fluid.utils;
import fluid.input;
import fluid.style;
import fluid.backend;
import fluid.structs;

import fluid.io.hover;
import fluid.io.canvas;

@safe:


///
alias slider(T) = simpleConstructor!(Slider!T);

/// ditto
class Slider(T) : AbstractSlider {

    mixin enableInputActions;

    public {

        /// Value range of the slider.
        SliderRange!T range;

    }

    /// Create the slider using the given range as the set of possible values/steps.
    this(R)(R range, size_t index, void delegate() @safe changed = null)
    if (is(ElementType!R == T)) {

        this(params, range, changed);
        this.index = index;

    }

    /// ditto
    this(R)(R range, void delegate() @safe changed = null)
    if (is(ElementType!R == T)) {

        // TODO special-case empty sliders instead?
        assert(!range.empty, "Slider range must not be empty.");

        this.range = new SliderRangeImpl!R(range);
        this.changed = changed;

    }

    override bool isHovered() const {

        return super.isHovered || this is tree.hover;

    }

    override void drawImpl(Rectangle outer, Rectangle inner) {

        super.drawImpl(outer, inner);

    }

    override size_t length() {

        return range.length;

    }

    T value() {

        return range[index];

    }

}

///
unittest {

    // To create a slider, pass it a range
    slider!int(iota(0, 10));     // slider from 0 to 9
    slider!int(iota(0, 11, 2));  // 0, 2, 4, 6, 8, 10

    // Use any value and any random-access range
    slider!string(["A", "B", "C"]);

}

abstract class AbstractSlider : InputNode!Node {

    enum railWidth = 4;
    enum minStepDistance = 10;

    CanvasIO canvasIO;
    HoverIO hoverIO;

    public {

        /// Handle of the slider.
        SliderHandle handle;

        /// Index/current position of the slider.
        size_t index;

    }

    protected {

        /// Position of the first step hitbox on the X axis.
        float firstStepX;

        /// Distance between each step
        float stepDistance;

    }

    private {

        bool _isPressed;

    }

    this() {

        alias sliderHandle = simpleConstructor!SliderHandle;

        this.handle = sliderHandle();

    }

    bool isPressed() const {

        return _isPressed;

    }

    override void resizeImpl(Vector2 space) {

        use(canvasIO);
        use(hoverIO);

        resizeChild(handle, space);
        minSize = handle.minSize;

    }

    override void drawImpl(Rectangle outer, Rectangle inner) {

        auto style = pickStyle();

        const rail = Rectangle(
            outer.x, center(outer).y - railWidth/2,
            outer.width, railWidth
        );

        // Check if the slider is pressed
        _isPressed = checkIsPressed();

        // Draw the rail
        style.drawBackground(io, canvasIO, rail);

        const availableWidth = rail.width - handle.size.x;
        const handleOffset = availableWidth * index / (length - 1f);
        const handleRect = Rectangle(
            rail.x + handleOffset, center(rail).y - handle.size.y/2,
            handle.size.x, handle.size.y,
        );

        // Draw steps; Only draw beginning and end if there's too many
        const stepCount = availableWidth / length >= minStepDistance
            ? length
            : 2;
        const visualStepDistance = availableWidth / (stepCount - 1f);

        stepDistance = availableWidth / (length - 1f);
        firstStepX = rail.x + handle.size.x / 2;

        foreach (step; 0 .. stepCount) {

            const start = Vector2(firstStepX + visualStepDistance * step, end(rail).y);
            const end = Vector2(start.x, end(outer).y);

            style.drawLine(io, canvasIO, start, end);

        }

        // Draw the handle
        drawChild(handle, handleRect);

    }

    @(FluidInputAction.press, WhileHeld)
    protected void press(HoverPointer pointer) {

        // Get mouse position relative to the first step
        const offset = pointer.position.x - firstStepX + stepDistance/2;

        // Get step based on X axis position
        const step = cast(size_t) (offset / stepDistance);

        // Validate the value
        if (step >= length) return;

        // Set the index
        if (index != step) {

            index = step;
            if (changed) changed();

        }

    }

    @(FluidInputAction.press, WhileDown)
    protected void press() {

        // The new I/O system will call the other overload.
        // Call it as a polyfill for the old system.
        if (!hoverIO) {
            HoverPointer pointer;
            pointer.position = io.mousePosition;
            press(pointer);
        }

    }

    @(FluidInputAction.scrollLeft)
    void decrement() {

        if (index > 0) index--;

    }

    @(FluidInputAction.scrollRight)
    void increment() {

        if (index + 1 < length) index++;

    }

    /// Length of the range.
    abstract size_t length();

}

interface SliderRange(Element) {

    alias Length = size_t;

    Element front();
    void popFront();
    Length length();
    Element opIndex(Length length);

}

class SliderRangeImpl(T) : SliderRange!(ElementType!T) {

    static assert(isRandomAccessRange!T);
    static assert(hasLength!T);

    T range;

    this(T range) {

        this.range = range;

    }

    ElementType!T front() {

        return range.front;

    }

    void popFront() {

        range.popFront;

    }

    Length length() {

        return range.length;

    }

    ElementType!T opIndex(Length length) {

        return range[length];

    }

}

/// Defines the handle of a slider.
class SliderHandle : Node {

    CanvasIO canvasIO;

    public {

        Vector2 size = Vector2(16, 20);

    }

    this() {

        ignoreMouse = true;

    }

    override void resizeImpl(Vector2 space) {

        use(canvasIO);
        minSize = size;

    }

    override void drawImpl(Rectangle outer, Rectangle inner) {

        style.drawBackground(io, canvasIO, outer);

    }

}
