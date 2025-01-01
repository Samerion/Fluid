///
module fluid.hover_chain;

import std.array;
import std.algorithm;

import fluid.node;
import fluid.types;
import fluid.utils;
import fluid.node_chain;

import fluid.io.hover;
import fluid.io.focus;
import fluid.io.action;

import fluid.future.arena;
import fluid.future.action;

@safe:

alias hoverChain = nodeBuilder!HoverChain;

/// A hover chain can be used to separate hover in different areas of the user interface, effectively treating them
/// like separate windows. A device node (like a mouse) can be placed to control nodes inside.
///
/// `HoverChain` has to be placed inside `FocusIO` to enable switching focus by pressing nodes.
///
/// For focus-based nodes like keyboard and gamepad, see `FocusChain`.
///
/// `HoverChain` only works with nodes compatible with the new I/O system introduced in Fluid 0.7.2.
class HoverChain : NodeChain, HoverIO {

    ActionIO actionIO;
    FocusIO focusIO;

    private {

        struct HoverPointer {

            /// The stored pointer.
            Pointer value;

            /// Branch action associated with the pointer; finds the associated node.
            FindHoveredNodeAction action;

            /// Node last matched to the pointer. "Hovered" node.
            Node node;

            /// Node that is being held, placed under the cursor at the time a button has been pressed.
            /// Input actions won't fire if the hovered node, the one under the cursor, is different from the one
            /// that is being held.
            Node heldNode;

            /// Scrollable hovered by this pointer, if any.
            HoverScrollable scrollable;

            /// If true, any button related to the pointer is being held.
            ///
            /// `heldNode` will not be updated while this is true, and current focus will be updated to match
            /// the hovered node.
            bool isHeld;

            /// If true, the pointer already handled incoming input events.
            bool isHandled;

            bool opEquals(const Pointer pointer) const {
                return this.value.isSame(pointer);
            }

        }

        ResourceArena!HoverPointer _pointers;

    }

    this() {

    }

    this(Node next) {
        super(next);
    }

    override int load(Pointer pointer)
    out(r) {
        import std.format;
        debug assert(_pointers.allResources.count(pointer) == 1,
            format!"Duplicate pointers created: %(\n  %s%)"(_pointers.allResources));
    }
    do {

        const index = cast(int) _pointers.allResources.countUntil(pointer);

        // No such pointer
        if (index == -1) {
            const newIndex = _pointers.load(HoverPointer(
                pointer,
                new FindHoveredNodeAction,
            ));
            _pointers[newIndex].value.load(this, newIndex);
            return newIndex;
        }

        // Found, update the pointer
        else {
            auto updatedPointer = _pointers[index];
            updatedPointer.value.update(pointer);
            updatedPointer.value.load(this, index);
            _pointers.reload(index, updatedPointer);
            return index;
        }

    }

    override inout(Pointer) fetch(int number) inout {

        assert(_pointers.isActive(number), "Pointer is not active");

        return _pointers[number].value;

    }

    override void emitEvent(Pointer pointer, InputEvent event) {

        assert(_pointers.isActive(pointer.id), "Pointer is not active");

        // Mark the pointer as held
        _pointers[pointer.id].isHeld = true;

        // Emit the event
        if (actionIO) {
            actionIO.emitEvent(event, pointer.id, &runInputAction);
        }

    }

    override bool isHovered(const Hoverable hoverable) const {

        foreach (pointer; _pointers.activeResources) {

            // Skip disabled pointers
            if (pointer.value.isDisabled) continue;

            // Check for matches
            if (hoverable.opEquals(pointer.node)) {
                return true;
            }

        }

        return false;

    }

    override int opApply(int delegate(Hoverable) @safe yield) {

        foreach (pointer; _pointers.activeResources) {

            // Skip disabled pointers
            if (pointer.value.isDisabled) continue;

            // List each hoverable
            if (auto hoverable = cast(Hoverable) pointer.node) {
                if (auto result = yield(hoverable)) {
                    return result;
                }
            }

        }

        return 0;

    }

    override void beforeResize(Vector2) {

        use(actionIO);
        use(focusIO);
        _pointers.startCycle();

        auto frame = controlIO!HoverIO();
        frame.start();
        frame.release();

    }

    override void afterResize(Vector2) {

        auto frame = controlIO!HoverIO();
        frame.stop();

    }

    override void beforeDraw(Rectangle outer, Rectangle inner) {

        // Find the current hover in child nodes
        auto frame = controlBranchAction(armBranchActions);
        frame.start();
        frame.release();

    }

    override void afterDraw(Rectangle outer, Rectangle inner) {

        auto frame = controlBranchAction(armBranchActions);
        frame.stop();

        // Update hover data
        foreach (pointer; _pointers.activeResources) {

            scope (exit) _pointers[pointer.value.id] = pointer;

            // Keep the same hovered node if the pointer is being held,
            // otherwise switch.
            pointer.node = pointer.action.result;
            if (!pointer.isHeld) {
                pointer.heldNode = pointer.node;
            }

            // Switch focus to hovered node if holding
            else if (focusIO) {
                if (auto focusable = pointer.heldNode.castIfAcceptsInput!Focusable) {
                    if (!focusable.isFocused) {
                        focusable.focus();
                    }
                }
                else {
                    focusIO.clearFocus();
                }
            }

            // Update scroll and send new events
            if (!pointer.value.isScrollHeld) {
                pointer.scrollable = pointer.action.scrollable;
            }
            if (pointer.scrollable) {
                pointer.scrollable.scrollImpl(pointer.value.scroll);
            }

            // Reset state
            pointer.isHeld = false;
            pointer.isHandled = false;

            // Send a frame event to trigger hoverImpl
            if (actionIO) {
                actionIO.emitEvent(ActionIO.frameEvent, pointer.value.id, &runInputAction);
            }
            else if (auto hoverable = pointer.node.castIfAcceptsInput!Hoverable) {
                pointer.isHandled = hoverable.hoverImpl();
            }

        }

    }

    /// List all branch actions for active pointers, and change their search positions to match the pointer.
    private auto armBranchActions() {

        return _pointers.activeResources
            .filter!(a => !a.value.isDisabled)
            .map!((a) {
                a.action.search = a.value.position;
                a.action.scroll = a.value.scroll;
                return a.action;
            });

    }

    override inout(Hoverable) hoverOf(Pointer pointer) inout {

        debug assert(_pointers.isActive(pointer.id), "Given pointer wasn't loaded");

        return _pointers[pointer.id].heldNode.castIfAcceptsInput!Hoverable;

    }

    override inout(HoverScrollable) scrollOf(Pointer pointer) inout {

        debug assert(_pointers.isActive(pointer.id), "Given pointer wasn't loaded");

        return _pointers[pointer.id].scrollable;

    }

    /// Handle an input action associated with a pointer.
    /// Params:
    ///     pointer  = Pointer to send the input action. It must be loaded.
    ///         The input action will be loaded by the node the pointer points at.
    ///     actionID = ID of the input action.
    ///     isActive = If true, the action has been activated during this frame.
    /// Returns:
    ///     True if the input action was handled.
    bool runInputAction(Pointer pointer, InputActionID actionID, bool isActive = true) {

        auto hover = hoverOf(pointer);
        auto meta = _pointers[pointer.id];

        // Active input actions can only fire if `heldNode` is still hovered
        if (isActive) {
            if (meta.node is null || !meta.node.opEquals(meta.heldNode)) {
                return false;
            }
        }

        // Try to handle the action
        const handled =

            // Try to run the action
            (hover && hover.actionImpl(this, pointer.id, actionID, isActive))

            // Run local input actions as fallback
            || runLocalInputActions(pointer, actionID, isActive)

            // Run hoverImpl as a last resort
            || (actionID == inputActionID!(ActionIO.CoreAction.frame) && hover && hover.hoverImpl());

        // Mark as handled, if so
        _pointers[pointer.id].isHandled = meta.isHandled || handled;

        return handled;

    }

    /// ditto
    bool runInputAction(alias action)(Pointer pointer, bool isActive = true) {

        const id = inputActionID!action;

        return runInputAction(pointer, id, isActive);

    }

    /// ditto
    protected final bool runInputAction(InputActionID actionID, bool isActive, int number) {

        return runInputAction(_pointers[number].value, actionID, isActive);

    }

    /// Run an input action implemented by this node. `HoverChain` does not implement any by default.
    /// Params:
    ///     pointer  = Pointer associated with the event.
    ///     actionID = ID of the input action to perform.
    ///     isActive = If true, the action has been activated during this frame.
    /// Returns:
    ///     True if the action was handled, false if not.
    protected bool runLocalInputActions(Pointer pointer, InputActionID actionID, bool isActive = true) {

        return false;

    }

}
