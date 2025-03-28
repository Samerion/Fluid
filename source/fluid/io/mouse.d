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

    mixin inputEvents!(MouseIO, Button);

    ///
    @("MouseIO.codes resolves into input event codes")
    unittest {

        assert(MouseIO.codes.left == MouseIO.getCode(MouseIO.Button.left));
        assert(MouseIO.codes.right == MouseIO.getCode(MouseIO.Button.right));

    }

    alias press = click;
    alias release = click;

    ///
    @("MouseIO.hold resolves into input events")
    unittest {

        assert(MouseIO.hold.left == MouseIO.createEvent(MouseIO.Button.left, false));
        assert(MouseIO.release.left == MouseIO.createEvent(MouseIO.Button.left, true));

        assert(MouseIO.hold.right == MouseIO.createEvent(MouseIO.Button.right, false));
        assert(MouseIO.release.right == MouseIO.createEvent(MouseIO.Button.right, true));

    }

    enum Button {
        none,
        left,         // Left (primary) mouse button.
        right,        // Right (secondary) mouse button.
        middle,       // Middle mouse button.
        extra1,       // Additional mouse button.
        extra2,       // ditto
        forward,      // Mouse button going forward in browser history.
        back,         // Mouse button going back in browser history.

        primary = left,
        secondary = right,

    }

}
