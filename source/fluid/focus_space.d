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

    override void resizeImpl(Vector2 space) {

        auto frame = implementIO!FocusSpace();

        use(actionIO);

        super.resizeImpl(space);

    }

    override void drawImpl(Rectangle outer, Rectangle inner) {

        _wasInputHandled = false;
        super.drawImpl(outer, inner);

    }

    void runInputAction(InputActionID id) {

        // Do nothing if there is no focus
        if (_focus is null) return;

        // Run the action, and mark input as handled
        if (_focus.actionImpl(id)) {
            _wasInputHandled = true;
        }

    }

    override void emitEvent(InputEvent event) {

        if (actionIO) {
            actionIO.emitEvent(event, &runInputAction);
        }

    }

    override inout(Focusable) focus() inout {

        return _focus;

    }

    override Focusable focus(Focusable newFocus) {

        return _focus = newFocus;

    }

}

/// Simulating keyboard input using an automaton node.
version (TODO)
unittest {

    KeyboardAutomaton keyboard;
    TextInput username;

    auto root = focusSpace(
        username = textInput(),

        // Place a keyboard node 
        keyboard = keyboardAutomaton(),
    );

    root.draw();

    // Type a word into the input using the keyboard automaton
    keyboard.type("Lei");
    assert(username.value == "Lei");

}
