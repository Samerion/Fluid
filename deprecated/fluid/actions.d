/// Definitions for common tree actions; This is the Fluid tree equivalent to std.algorithm.
deprecated("Module `fluid.actions` has been replaced. "
    ~ "Update to `fluid.io.focus` for `focusRecurse` and `focusRecurseChildren`; "
    ~ "Update to `fluid.io.scroll` for `scrollIntoView` and `scrollToTop`. "
    ~ "`fluid.actions` will be removed in Fluid 0.9.0.")
module fluid.actions;

public import fluid.io.focus;
public import fluid.io.scroll;
