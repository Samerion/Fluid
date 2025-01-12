/// Module handling low-level user preferences, like the double click interval.
module fluid.io.preference;

import core.time;

import fluid.future.context;

@safe:

/// I/O interface for loading low-level user preferences, such as the double click interval, from the system.
///
/// Right now, this interface only includes the double click interval. Other user-specific preference options
/// may be added in the future if they need to be handled at Fluid's level. When this happens, they will first
/// be added through a separate interface, and become merged on a major release.
///
/// Using values from the system, rather than guessing or supplying our own, has benefits for accessibility.
/// These preferences help people of varying age and reaction times, or with disabilities related to vision
/// and muscular function.
interface PreferenceIO : IO {

    /// Get the double click interval from the system
    ///
    /// This interval defines the maximum amount of time that can pass between two clicks for a double click event
    /// to trigger, or, between each individual click in a triple click sequence. Detecting double clicks has to be
    /// implemented at node level, and double clicks do not normally have a corresponding input action.
    ///
    /// If caching is necessary, it has to be done at I/O level. This way, the I/O system may support reloading
    /// preferences at runtime.
    ///
    /// Returns:
    ///     The double click interval.
    Duration doubleClickInterval() const nothrow;

}
