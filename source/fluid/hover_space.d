/// 
module fluid.hover_space;

import std.array;
import std.algorithm;

import fluid.node;
import fluid.space;
import fluid.types;
import fluid.utils;

import fluid.io.hover;
import fluid.io.action;

import fluid.future.arena;
import fluid.future.action;

@safe:

alias hoverSpace = nodeBuilder!HoverSpace;

/// A hover space can be used to separate hover in different areas of the user interface, effectively treating them
/// like separate windows. A device node (like a mouse) can be placed to control nodes inside.
///
/// For focus-based nodes like keyboard and gamepad, see `FocusSpace`.
///
/// `HoverSpace` only works with nodes compatible with the new I/O system introduced in Fluid 0.7.2.
class HoverSpace : Space, HoverIO {

    ActionIO actionIO;

    private {

        struct HoverPointer {

            Pointer value;
            NodeAtPointAction action;
            Node node;

            bool opEquals(const Pointer pointer) const {
                return this.value.isSame(pointer);
            }

        }

        ResourceArena!HoverPointer _pointers;

    }

    this(Node[] nodes...) {

        super(nodes);

    }

    override int load(Pointer pointer) {

        const index = cast(int) _pointers[].countUntil(pointer);

        // No such pointer
        if (index == -1) {
            return _pointers.load(HoverPointer(
                pointer,
                new NodeAtPointAction,
            ));
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

    override void emitEvent(Pointer pointer, InputEvent event) {

        if (!actionIO) return;

        actionIO.emitEvent(event, pointer.id, &runInputAction);
        
    }

    override int opApply(int delegate(Hoverable) @safe yield) {

        foreach (pointer; _pointers[]) {

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

    override void resizeImpl(Vector2 space) {

        use(actionIO);
        _pointers.startCycle();

        auto frame = implementIO!HoverSpace();
        super.resizeImpl(space);

    }

    override void drawImpl(Rectangle outer, Rectangle inner) {

        // Draw the children and find the current hover
        {
            auto frame = startBranchAction(armBranchActions);
            super.drawImpl(outer, inner);
        }

        // Update hover data
        foreach (ref pointer; _pointers[]) {
            pointer.node = pointer.action.result;
        }

    }

    /// List all branch actions for active pointers, and change their search positions to match the pointer.
    private auto armBranchActions() {

        return _pointers[]
            .filter!(a => !a.value.isDisabled)
            .map!((a) {
                a.action.search = a.value.position;
                return a.action;
            });

    }

    /// Returns:
    ///     Node hovered by the pointer.
    /// Params:
    ///     pointer = Pointer to check. The pointer must be loaded.
    Node hoverOf(Pointer pointer) {

        assert(_pointers.isActive(pointer.id), "Given pointer wasn't loaded");

        return _pointers[pointer.id].node;

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

        auto hover = cast(Hoverable) hoverOf(pointer);

        // Run the action, and mark input as handled
        if (hover && hover.actionImpl(actionID, isActive)) {
            return true;
        }

        // Run local input actions
        if (runLocalInputActions(pointer, actionID, isActive)) {
            return true;
        }

        return false;

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

    /// Run an input action implemented by this node. HoverSpace does not implement any by default.
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
