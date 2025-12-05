/// Time management functionality for Fluid nodes.
///
/// Fluid nodes rely on passage of time to perform animations or sync input (like double clicking).
/// To measure time, nodes need a source of time, which they can obtain through `TimeIO`.
/// Most of the time, this is the system clock (implemented by `fluid.time_chain.TimeChain`), but for testing,
/// passage of time should be controlled by the test suite (implemented by `fluid.time_machine.TimeMachine`).
module fluid.io.time;

import core.time;

import fluid.future.context;

@safe:

/// Interface for accessing the system clock.
///
/// `TimeIO` uses `MonoTime` and fetches current time for the purpose of comparison. `MonoTime` is a monotonic
/// clock, so it only goes forward, and cannot be adjusted.
///
/// See_Also:
///     `core.time.MonoTime`.
interface TimeIO : IO {

    /// Returns: The current time.
    MonoTime now() nothrow;

    /// Params:
    ///     event = Timestamp obtained earlier from `TimeIO`.
    /// Returns:
    ///     Time elapsed since the timestamp.
    final Duration timeSince(MonoTime event) nothrow {
        return now() - event;
    }

}
