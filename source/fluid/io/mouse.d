/// This module contains interfaces for handling mouse actions.
module fluid.io.mouse;

import fluid.future.context;

import fluid.io.action;

@safe:

/// I/O interface for emitting mouse events.
///
/// While a mouse button is held down, it will emit inactive input events. The moment a mouse button is released,
/// it will emit an active event. This is unlike keyboard events in the sense that a mouse button will emit an event
/// one frame after it is no longer held.
///
/// A `MouseIO` system will usually pass events to a `HoverIO` system it is child of.
interface MouseIO : IO {

    /// Get the input event code for a mouse button.
    /// Params:
    ///     button = Button to fetch the code for.
    /// Returns:
    ///     Input event code that can be used for input event routines.
    static InputEventCode getCode(Button button) {

        return InputEventCode(ioID!MouseIO, button);

    }

    /// A shortcut for getting input event codes that are known at compile time. Handy for tests.
    /// Returns: A struct with event code for each member, corresponding to members of `Button`.
    static codes() {

        static struct Codes {
            static InputEventCode opDispatch(string name)() {
                return getCode(__traits(getMember, MouseIO.Button, name));
            }
        }

        return Codes();

    }

    ///
    @("MouseIO.codes resolves into input event codes")
    unittest {

        assert(MouseIO.codes.left == MouseIO.getCode(MouseIO.Button.left));
        assert(MouseIO.codes.right == MouseIO.getCode(MouseIO.Button.right));

    }

    /// Create a mouse input event that can be passed to a `HoverIO` or `ActionIO` handler.
    ///
    /// Params:
    ///     button   = Button that is held down or was just released.
    ///     isActive = True if the button was just released.
    /// Returns:
    ///     The created input event.
    static InputEvent createEvent(Button button, bool isActive) {

        const code = getCode(button);
        return InputEvent(code, isActive);

    }

    enum Button {
        none,
        left,         // Left (primary) mouse button.
        right,        // Right (secondary) mouse button.
        middle,       // Middle mouse button.
        extra1,       // Additional mouse button.
        extra2,       // ditto.
        forward,      // Mouse button going forward in browser history.
        back,         // Mouse button going back in browser history.

        primary = left,
        secondary = right,

    }

}
