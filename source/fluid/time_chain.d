/// Monotonic clock implementation as a node.
module fluid.time_chain;

import core.time;

import fluid.node;
import fluid.utils;
import fluid.types;
import fluid.node_chain;

import fluid.io.time;

@safe:

alias timeChain = nodeBuilder!TimeChain;

/// Fetches system time, enabling nodes to measure time elapsed between events occurring in the node tree.
///
/// See_Also:
///     `core.time.MonoTime`, `fluid.io.time.TimeIO`
class TimeChain : NodeChain, TimeIO {

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

    override MonoTime now() nothrow {
        return MonoTime.currTime();
    }

}
