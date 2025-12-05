/// Implementation of `PreferenceIO`, providing values that depend on the system and the user.
module fluid.preference_chain;

import core.time;

import fluid.node;
import fluid.types;
import fluid.utils;
import fluid.node_chain;

import fluid.io.preference;

@safe:

alias preferenceChain = nodeBuilder!PreferenceChain;

/// PreferenceChain implements `PreferenceIO`, accessing crucial, low-level user preferences that affect their usage
/// of Fluid programs.
///
/// Currently, `PreferenceChain` does *not* communicate with the system, and instead assumes a default value of 400
/// milliseconds for the double-click interval, and 6 pixels for the maximum double click distance. Communicating
/// with the system will be enabled in a future update through a `version` flag. See
/// [issue #295](https://git.samerion.com/Samerion/Fluid/issues/295) for more details.
class PreferenceChain : NodeChain, PreferenceIO {

    mixin controlIO;

    this(Node next = null) {
        super(next);
    }

    override void beforeResize(Vector2) {
        startIO();
    }

    override void afterResize(Vector2) {
        stopIO();
    }

    override Duration doubleClickInterval() const nothrow {
        return 400.msecs;
    }

    override float maximumDoubleClickDistance() const nothrow {
        return 6;
    }

    override Vector2 scrollSpeed() const nothrow {

        // Normalize the value: Linux and Windows provide trinary values (-1, 0, 1) but macOS gives analog that often
        // goes far higher than that. This is currently a rough guess of the proportions based on feeling.
        // See
        version (OSX)
            return Vector2(65 / 4, 65 / 4);
        else
            return Vector2(65, 65);

    }

}
