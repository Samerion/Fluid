/// Implementation of a clock adjusted programmatically, most for testing.
module fluid.time_machine;

import core.time;

import fluid.node;
import fluid.utils;
import fluid.types;
import fluid.node_chain;

import fluid.io.time;

@safe:

alias timeMachine = nodeBuilder!TimeMachine;

/// A time machine makes it possible to programmatically adjust and skip time that is used by Fluid nodes.
///
/// The main use of a `TimeMachine` is to artificially control passage of time while running tests. This means
/// that a test can imitate a change in time without waiting for it, speeding up tests.
///
/// See_Also:
///     `core.time.MonoTime`, `fluid.io.time.TimeIO`
class TimeMachine : NodeChain, TimeIO {

    public {
        MonoTime time;
    }

    this(Node next = null) {
        super(next);
        this.time = MonoTime.currTime();
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

    override MonoTime now() nothrow {
        return time;
    }

    /// Add, or subtract time from the machine's clock.
    /// Params:
    ///     rhs = Time value to add or subtract.
    /// Returns:
    ///     The same time machine.
    TimeMachine opOpAssign(string op)(Duration rhs) nothrow {
        time += rhs;
        return this;
    }

}
