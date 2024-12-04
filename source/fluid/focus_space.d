/// 
module fluid.focus_space;

import fluid.node;
import fluid.space;
import fluid.types;
import fluid.utils;

import fluid.io.focus;
import fluid.io.action;

@safe:

alias focusSpace = nodeBuilder!FocusSpace;

/// A focus space can be used to separate focus in different areas of the user interface. A device node
/// (focus-based, like a keyboard or gamepad) node can be placed to control nodes inside.
///
/// For hover-based nodes like mouse, see `HoverSpace`.
///
/// `FocusSpace` only works with nodes compatible with the new I/O system introduced in Fluid 0.7.2.
class FocusSpace : Space, FocusIO {

    ActionIO actionIO;

    private {

        Focusable _focus;
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

    override inout(Focusable) currentFocus() inout {
        return _focus;
    }

    override Focusable currentFocus(Focusable newFocus) {
        return _focus = newFocus;
    }


    override void resizeImpl(Vector2 space) {

        auto frame = implementIO!FocusSpace();

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
    ///     action   = Input action for the node to handle.
    ///     isActive = If true (default) the action is active, on top of being simply emitted. 
    ///         Most handlers only react to active actions.
    /// Returns:
    ///     True if the action was handled.
    ///     Consequently, `wasInputAction` will be set to true.
    bool runInputAction(InputActionID action, bool isActive = true) {

        // Do nothing if there is no focus
        if (_focus is null) return false;

        // Run the action, and mark input as handled
        if (_focus.actionImpl(action, isActive)) {
            _wasInputHandled = true;
            return true;
        }

        return false;

    }

    /// ditto
    bool runInputAction(alias action)(bool isActive = true) {

        const id = inputActionID!action;

        return runInputAction(id, isActive);

    }

    override void emitEvent(InputEvent event) {

        if (actionIO) {
            actionIO.emitEvent(event, &runInputAction);
        }

    }

}
