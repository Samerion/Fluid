///
module fluid.io.debug_signal;

import fluid.future.context;

@safe:

/// Debug signals are used to observe instances of specific events in tests. A node may emit signals on a function
/// call, and another node can test for these events to see if they occur (or don't), if the order is right, etc.
interface DebugSignalIO : IO {

    /// Emit a debug signal.
    /// Params:
    ///     name = Name of the signal.
    void emitSignal(string name) nothrow;

}
