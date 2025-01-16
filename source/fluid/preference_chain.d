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
/// with the system will be enabled in a future update through a `version` flag.
class PreferenceChain : NodeChain, PreferenceIO {

    this(Node next = null) {
        super(next);
    }

    override void beforeResize(Vector2) {
        auto frame = this.controlIO();
        frame.start();
        frame.release();
    }

    override void afterResize(Vector2) {
        auto frame = this.controlIO();
        frame.stop();
    }

    override Duration doubleClickInterval() const nothrow {
        return 400.msecs;
    }

    override float maximumDoubleClickDistance() const nothrow {
        return 6;
    }

}
