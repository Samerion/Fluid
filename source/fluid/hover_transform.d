module fluid.hover_transform;

import std.array;

import fluid.types;
import fluid.utils;
import fluid.node_chain;

import fluid.io.hover;

@safe:

alias hoverTransform = nodeBuilder!HoverTransform;

class HoverTransform : NodeChain, HoverIO {

    HoverIO hoverIO;

    public {

        /// By default, the destination rectangle is automatically updated to match the padding
        /// box of `HoverTransform`. If toggled on, it is instead static, and can be manually
        /// updated.
        bool isDestinationManual;

    }

    private {

        Rectangle _sourceRectangle;
        Rectangle _destinationRectangle;

        /// Pointers received from the host.
        Appender!(Pointer[]) _pointers;

    }

    /// Params:
    ///     sourceRectangle      = Rectangle the input is expected to fit in.
    ///     destinationRectangle = Rectangle to map the input to. If omitted, chosen automatically
    ///         so that input is remapped to the content of this node.
    this(Rectangle sourceRectangle) {
        this._sourceRectangle = sourceRectangle;
        this.isDestinationManual = false;
    }

    /// ditto
    this(Rectangle sourceRectangle, Rectangle destinationRectangle) {
        this._sourceRectangle = sourceRectangle;
        this._destinationRectangle = destinationRectangle;
        this.isDestinationManual = true;
    }

    /// Returns:
    ///     Rectangle for hover input. This input will be transformed to match
    ///     `destinationRectangle`.
    Rectangle sourceRectangle() const {
        return _sourceRectangle;
    }

    /// Change the source rectangle.
    /// Params:
    ///     newValue = New value for the rectangle.
    /// Returns:
    ///     Same value as passed.
    Rectangle sourceRectangle(Rectangle newValue) {
        return _sourceRectangle = newValue;
    }

    /// Returns:
    ///     Rectangle for output. By default, this should match the padding box of this node,
    ///     unless explicitly changed to something else.
    Rectangle destinationRectangle() const {
        if (tree)
            return _destinationRectangle;
        else
            return sourceRectangle;
    }

    /// Change the destination rectangle, disabling automatic destination selection.
    ///
    /// Changing destination rectangle sets `isDestinationManual` to `true`. Set it to false if
    /// you want the destination rectangle to match the node's padding box instead.
    ///
    /// See_Also:
    ///     `isDestinationManual`
    Rectangle destinationRectangle(Rectangle newValue) {
        isDestinationManual = true;
        return _destinationRectangle = newValue;
    }

    /// Transform a point in `sourceRectangle` onto `destinationRectangle`.
    /// Params:
    ///     point = Point to transform.
    /// Returns:
    ///     Transformed point.
    Vector2 transformPoint(Vector2 point) const {
        return point.viewportTransform(sourceRectangle, destinationRectangle);
    }

    /// Transform a pointer into a new position.
    ///
    /// This will convert the pointer into a pointer within this node. The pointer *must*
    /// be loaded in the host `HoverIO`.
    ///
    /// Params:
    ///     pointer = Pointer to transform.
    /// Returns:
    ///     Transformed pointer.
    inout(HoverPointer) transformPointer(inout HoverPointer pointer) inout @trusted {
        assert(pointer.system, "Hover pointer must be loaded");
        assert(pointer.system.opEquals(cast(const Object) hoverIO),
            "Pointer must come from the host HoverIO system");

        HoverPointer result;
        result.update(pointer);
        result.position = transformPoint(pointer.position);
        return cast(inout) result.loadCopy(this, pointer.id);
    }

    override void beforeResize(Vector2) {
        require(hoverIO);
        this.controlIO().startAndRelease();
    }

    override void afterResize(Vector2) {
        this.controlIO().stop();
    }

    /// `HoverTransform` saves all the pointers it receives from the host `HoverIO`
    /// and creates local copies. It then transforms those, and checks its children for
    /// matching nodes.
    override void beforeDraw(Rectangle outer, Rectangle inner) {

        if (!isDestinationManual) {
            _destinationRectangle = outer;
        }

        _pointers.clear();
        foreach (HoverPointer pointer; hoverIO) {
            _pointers ~= Pointer();
        }

    }

    override int load(HoverPointer pointer) {
        assert(false, "TODO");
    }

    inout(HoverPointer) fetch(int number) inout {
        auto pointer = hoverIO.fetch(number);
        return transformPointer(pointer);
    }

    void emitEvent(HoverPointer pointer, InputEvent event) {
        assert(false, "TODO");
    }

    inout(Hoverable) hoverOf(HoverPointer pointer) inout {
        assert(false, "TODO");
    }

    inout(HoverScrollable) scrollOf(HoverPointer pointer) inout {
        assert(false, "TODO");
    }

    bool isHovered(const Hoverable hoverable) const {
        assert(false, "TODO");
    }

    int opApply(int delegate(HoverPointer) @safe yield) {
        foreach (HoverPointer pointer; hoverIO) {

            auto transformed = transformPointer(pointer);
            if (auto result = yield(transformed)) {
                return result;
            }

        }
        return 0;
    }

    int opApply(int delegate(Hoverable) @safe yield) {
        assert(false, "TODO");
    }

}

private struct Pointer {

}
