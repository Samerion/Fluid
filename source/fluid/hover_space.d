/// 
module fluid.hover_space;

import fluid.node;
import fluid.space;
import fluid.types;
import fluid.utils;

import fluid.io.hover;
import fluid.io.action;

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

        Hoverable _hover;
        bool _wasInputHandled;

    }

    this(Node[] nodes...) {

        super(nodes);

    }

    /// If a node inside `FocusSpace` triggers an input event (for example a keyboard node, 
    /// like a keyboard automaton), another node in the space may handle the event. This property
    /// will be set to true after that happens.
    ///
    /// This status is reset the moment this frame is updated again.
    ///
    /// Returns:
    ///     True, if an input action launched during the last frame was passed to a focused node and handled.
    bool wasInputHandled() const {

        return _wasInputHandled;

    }

    override inout(Hoverable) hover() inout {
        return _hover;
    }

    override Hoverable hover(Hoverable newHover) {
        return _hover = newHover;
    }


    override void resizeImpl(Vector2 space) {

        auto frame = implementIO!HoverSpace();

        use(actionIO);

        super.resizeImpl(space);

    }

    override void drawImpl(Rectangle outer, Rectangle inner) {

        _wasInputHandled = false;
        super.drawImpl(outer, inner);

    }

    /// Handle an input action using the currently focused node.
    ///
    /// Does nothing if no node has focus.
    ///
    /// Params:
    ///     action = Input action for the node to handle.
    /// Returns:
    ///     True if the action was handled.
    ///     Consequently, `wasInputAction` will be set to true.
    bool runInputAction(InputActionID action) {

        // Do nothing if there is no focus
        if (_hover is null) return false;

        // Run the action, and mark input as handled
        if (_hover.actionImpl(action)) {
            _wasInputHandled = true;
            return true;
        }

        return false;

    }

    /// ditto
    bool runInputAction(alias action)() {

        const id = inputActionID!action;

        return runInputAction(id);

    }

    override void emitEvent(InputEvent event) {

        if (actionIO) {
            actionIO.emitEvent(event, &handleAction);
        }

    }

    private void handleAction(InputActionID id) {
        runInputAction(id);
    }

}
