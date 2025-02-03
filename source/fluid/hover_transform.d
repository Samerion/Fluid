module fluid.hover_transform;

import std.array;
import std.algorithm;

import fluid.node;
import fluid.types;
import fluid.utils;
import fluid.node_chain;

import fluid.io.hover;
import fluid.io.action;

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

        /// Pool of actions that are used to find matching nodes.
        FindHoveredNodeAction[] _actions;

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
        size_t index;
        foreach (HoverPointer pointer; hoverIO) {
            scope (exit) index++;
            if (pointer.isDisabled) continue;

            _pointers ~= Pointer(pointer.id);

            // Allocate a branch action for each pointer
            if (index >= _actions.length) {
                _actions.length = index + 1;
                _actions[index] = new FindHoveredNodeAction;
            }

            _actions[index].search = pointer.position;
            _actions[index].scroll = pointer.scroll;
            controlBranchAction(_actions[index]).startAndRelease();
        }

    }

    override void afterDraw(Rectangle outer, Rectangle inner) {
        foreach (index, ref pointer; _pointers[]) {
            auto action = _actions[index];
            controlBranchAction(_actions[index]).stop();

            // Read the result of each action into the local pointer
            pointer.hoveredNode = action.result;
            if (!pointer.isHeld) {
                pointer.heldNode = pointer.hoveredNode;
            }
            if (!pointer.isScrollHeld) {
                pointer.scrollable = action.scrollable;
            }
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

    private inout(Pointer) getPointerData(int id) inout {
        auto result = _pointers[].find!"a.id == b"(id);
        if (result.empty) {
            return Pointer.init;
        }
        else {
            return result.front;
        }
    }

    inout(Hoverable) hoverOf(HoverPointer pointer) inout {
        return getPointerData(pointer.id).heldNode.castIfAcceptsInput!Hoverable;
    }

    inout(HoverScrollable) scrollOf(HoverPointer pointer) inout {
        return getPointerData(pointer.id).scrollable;
    }

    bool isHovered(const Hoverable hoverable) const {
        foreach (pointer; _pointers[]) {
            if (hoverable.opEquals(pointer.heldNode)) {
                return true;
            }
        }
        return false;
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
    int id;
    Node heldNode;
    Node hoveredNode;
    HoverScrollable scrollable;
    bool isHeld;
    bool isScrollHeld;
}
