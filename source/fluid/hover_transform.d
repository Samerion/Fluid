module fluid.hover_transform;

import std.array;
import std.string;
import std.algorithm;

import fluid.node;
import fluid.types;
import fluid.utils;
import fluid.structs;
import fluid.node_chain;

import fluid.future.arena;
import fluid.future.context;

import fluid.io.hover;
import fluid.io.action;

@safe:

alias hoverTransform = nodeBuilder!HoverTransform;

class HoverTransform : NodeChain, HoverIO, Hoverable, HoverScrollable {

    HoverIO hoverIO;

    public {

        /// By default, the destination rectangle is automatically updated to match the padding
        /// box of the transform's child node. If toggled on, it is instead static, and can be
        /// manually updated.
        bool isDestinationManual;

    }

    private {

        Rectangle _sourceRectangle;
        Rectangle _destinationRectangle;

        /// Pointers received from the host.
        ResourceArena!Pointer _pointers;

        /// Pool of actions that are used to find matching nodes.
        FindHoveredNodeAction[] _actions;

        typeof(controlIO!HoverIO()) _ioFrame;

    }

    /// Params:
    ///     sourceRectangle      = Rectangle the input is expected to fit in.
    ///     destinationRectangle = Rectangle to map the input to. If omitted, chosen automatically
    ///         so that input is remapped to the content of this node.
    ///     next                 = Node to be affected by the transform.
    this(Rectangle sourceRectangle, Node next = null) {
        this._sourceRectangle = sourceRectangle;
        this.isDestinationManual = false;
        super(next);
    }

    /// ditto
    this(Rectangle sourceRectangle, Rectangle destinationRectangle, Node next = null) {
        this._sourceRectangle = sourceRectangle;
        this._destinationRectangle = destinationRectangle;
        this.isDestinationManual = true;
        super(next);
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
    /// See_Also:
    ///     `pointToHost` for the reverse transformation.
    /// Params:
    ///     point = Point, in host space, to transform.
    /// Returns:
    ///     Point transformed into local space.
    Vector2 pointToLocal(Vector2 point) const {
        return point.viewportTransform(sourceRectangle, destinationRectangle);
    }

    /// Transform a point in `destinationRectangle` onto `sourceRectangle`.
    /// See_Also:
    ///     `pointToLocal` for the reverse transformation.
    /// Params:
    ///     point = Point, in local space, to transform.
    /// Returns:
    ///     Point transformed into host space.
    Vector2 pointToHost(Vector2 point) const {
        return point.viewportTransform(destinationRectangle, sourceRectangle);
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
    inout(HoverPointer) pointerToLocal(inout HoverPointer pointer) inout @trusted {
        HoverPointer result;
        result.update(pointer);
        result.position = pointToLocal(pointer.position);
        return cast(inout) result.loadCopy(this, pointer.id);
    }

    /// Reverse pointer transform. Transform pointers from the local, transformed space, into the
    /// space of the host.
    ///
    /// This is used when loading pointers through `HoverTransform.load`. This way, devices placed
    /// inside the transform exist within the transformed space.
    ///
    /// Params:
    ///     pointer = Pointer to transform.
    /// Returns:
    ///     Transformed pointer.
    inout(HoverPointer) pointerToHost(inout HoverPointer pointer) inout @trusted {
        HoverPointer result;
        result.update(pointer);
        result.position = pointToHost(pointer.position);
        return cast(inout) result.loadCopy(hoverIO, pointer.id);
    }

    override void beforeResize(Vector2) {
        require(hoverIO);
        _ioFrame = controlIO!HoverIO().startAndRelease();
    }

    override void afterResize(Vector2) {
        _ioFrame.stop;
    }

    /// `HoverTransform` saves all the pointers it receives from the host `HoverIO`
    /// and creates local copies. It then transforms those, and checks its children for
    /// matching nodes.
    override void beforeDraw(Rectangle outer, Rectangle inner) {

        if (!isDestinationManual && next) {
            _destinationRectangle = next.paddingBoxForSpace(inner);
        }

        size_t actionIndex;

        foreach (HoverPointer pointer; hoverIO) {
            if (pointer.isDisabled) continue;

            auto transformed = pointerToLocal(pointer);
            const localID = cast(int) _pointers.allResources.countUntil(pointer.id);

            // Allocate a branch action for each pointer
            if (actionIndex >= _actions.length) {
                _actions.length = actionIndex + 1;
                _actions[actionIndex] = new FindHoveredNodeAction;
            }

            auto action = _actions[actionIndex++];
            action.pointer = transformed;
            controlBranchAction(action).startAndRelease();

            // Create or update pointer entries
            if (localID == -1) {
                const newLocalID = _pointers.load(Pointer(pointer.id, 0, action));
                _pointers[newLocalID].localID = newLocalID;
            }
            else {
                auto resource = _pointers[localID];
                resource.action = action;
                resource.localID = localID;
                _pointers.reload(localID, resource);
            }
        }

    }

    override void afterDraw(Rectangle outer, Rectangle inner) {
        foreach (pointer; _pointers.activeResources) {
            controlBranchAction(pointer.action).stop();

            // Read the result of each action into the local pointer
            pointer.hoveredNode = pointer.action.result;
            if (!pointer.isHeld) {
                pointer.heldNode = pointer.hoveredNode;
            }
            if (!pointer.isScrollHeld) {
                pointer.scrollable = pointer.action.scrollable;
            }

            _pointers[pointer.localID] = pointer;
        }
    }

    override int load(HoverPointer pointer) {
        auto hostPointer = pointerToHost(pointer);
        return hoverIO.load(hostPointer);
    }

    override inout(HoverPointer) fetch(int number) inout {
        auto pointer = hoverIO.fetch(number);
        return pointerToLocal(pointer);
    }

    override void emitEvent(HoverPointer pointer, InputEvent event) {
        auto hostPointer = pointerToHost(pointer);
        hoverIO.emitEvent(hostPointer, event);
    }

    private int hostToLocalID(int id) const {
        const localID = cast(int) _pointers.allResources.countUntil(id);
        assert(localID >= 0, format!"Pointer %s isn't loaded"(id));
        return localID;
    }

    override inout(Hoverable) hoverOf(HoverPointer pointer) inout {
        return hoverOf(pointer.id);
    }

    inout(Hoverable) hoverOf(int pointerID) inout {
        const localID = hostToLocalID(pointerID);
        return _pointers[localID].heldNode.castIfAcceptsInput!Hoverable;
    }

    override inout(HoverScrollable) scrollOf(const HoverPointer pointer) inout {
        return scrollOf(pointer.id);
    }

    inout(HoverScrollable) scrollOf(int pointerID) inout {
        const localID = hostToLocalID(pointerID);
        return _pointers[localID].scrollable;
    }

    override bool isHovered(const Hoverable hoverable) const {
        foreach (pointer; _pointers.activeResources) {
            if (hoverable.opEquals(pointer.heldNode)) {
                return true;
            }
        }
        return false;
    }

    override int opApply(int delegate(HoverPointer) @safe yield) {
        foreach (HoverPointer pointer; hoverIO) {

            auto transformed = pointerToLocal(pointer);
            if (auto result = yield(transformed)) {
                return result;
            }

        }
        return 0;
    }

    override int opApply(int delegate(Hoverable) @safe yield) {
        foreach (pointer; _pointers.activeResources) {
            if (auto hoverable = cast(Hoverable) pointer.heldNode) {
                if (auto result = yield(hoverable)) {
                    return result;
                }
            }
        }
        return 0;
    }

    override bool blocksInput() const {
        return isDisabled || isDisabledInherited;
    }

    override bool actionImpl(IO io, int hostID, immutable InputActionID actionID, bool isActive) {

        const localID = hostToLocalID(hostID);
        auto resource = _pointers[localID];
        const isFrameAction = actionID == inputActionID!(ActionIO.CoreAction.frame);

        // Active input actions can only fire if `heldNode` is still hovered
        if (isActive) {
            const isNotHovered = resource.hoveredNode is null
                || !resource.hoveredNode.opEquals(resource.heldNode);

            if (isNotHovered) {
                return false;
            }
        }

        // Mark pointer as held
        if (!isFrameAction) {
            _pointers[localID].isHeld = true;
        }

        // Dispatch the event
        if (auto target = resource.heldNode.castIfAcceptsInput!Hoverable) {
            return target.actionImpl(this, hostID, actionID, isActive);
        }
        return false;

    }

    override bool hoverImpl(HoverPointer pointer) {
        if (auto target = hoverOf(pointer)) {
            auto transformed = pointerToLocal(pointer);
            return target.hoverImpl(transformed);
        }
        return false;
    }

    override IsOpaque inBoundsImpl(Rectangle outer, Rectangle inner, Vector2 position) {
        if (super.inBoundsImpl(outer, inner, position).inSelf) {
            return IsOpaque.onlySelf;
        }
        return IsOpaque.no;
    }

    override bool isHovered() const {
        return hoverIO.isHovered(this);
    }

    override bool canScroll(const HoverPointer pointer) const {
        if (auto scroll = scrollOf(pointer)) {
            auto transformed = pointerToLocal(pointer);
            return scroll.canScroll(transformed);
        }
        return false;
    }

    override bool scrollImpl(HoverPointer pointer) {
        if (auto scroll = scrollOf(pointer)) {
            auto transformed = pointerToLocal(pointer);
            return scroll.scrollImpl(transformed);
        }
        else return false;
    }

    override Rectangle shallowScrollTo(const(Node) child, Rectangle parentBox, Rectangle childBox) {
        // TODO ???
        assert(false, "TODO");
    }

    alias opEquals = typeof(super).opEquals;
    override bool opEquals(const Object other) const {
        return super.opEquals(other);
    }

}

private struct Pointer {
    int hostID;
    int localID;
    FindHoveredNodeAction action;
    Node heldNode;
    Node hoveredNode;
    HoverScrollable scrollable;
    bool isHeld;
    bool isScrollHeld;

    /// Find a pointer by its host ID
    bool opEquals(int id) const {
        return this.hostID == id;
    }
}
