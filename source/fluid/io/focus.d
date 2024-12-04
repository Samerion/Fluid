/// This module implements interfaces for handling focus and connecting focusable nodes with input devices.
module fluid.io.focus;

import fluid.future.context;

import fluid.io.action;

@safe:

/// `FocusIO` is an input handler system that reads events off devices like keyboards or gamepads, which do not
/// map directly to screen coordinates.
///
/// Most of the time, `FocusIO` systems will pass the events they receive to an `ActionIO` system, and then send
/// these actions to a focused node.
///
/// Multiple different `FocusIO` instances can coexist in the same tree, allowing for multiple different nodes
/// to be focused at the same time, as long as they belong in different branches of the node tree. That means
/// two different nodes can be focused by two different `FocusIO` systems, but a single `FocusIO` system can only
/// focus a single node.
interface FocusIO : IO {

    /// Read an input event from an input device. Input devices will call this function every frame 
    /// if an input event occurs.
    ///
    /// `FocusIO` will usually pass these down to an `ActionIO` system. It is up to `FocusIO` to decide how 
    /// the input and the resulting input actions are handled, though they will most often be passed 
    /// to the focused node.
    ///
    /// Params:
    ///     event = Input event the system should save.
    void emitEvent(InputEvent event);

    /// Returns:
    ///     The currently focused node, or `null` if no node has focus at the moment.
    inout(Focusable) focus() inout;

    /// Change the currently focused node to another.
    ///
    /// This function may frequently be passed `null` with the intent of clearing the focused node.
    ///
    /// Params:
    ///     newValue = Node to assign focus to.
    /// Returns:
    ///     Node that was focused, to allow chaining assignments.
    Focusable focus(Focusable newValue);

}

/// Nodes implementing this interface can be focused by a `FocusIO` system.
interface Focusable : Actionable {

    /// Handle input. Called each frame when focused.
    /// Returns:
    ///     True if focus input was handled, false if it was ignored.
    bool focusImpl();

    /// Set focus to this node.
    ///
    /// Implementation would usually call `focusIO.focus` on self for this to take effect. A node may override this
    /// method to redirect the focus to another node (by calling its `focus()` method), or ignore the request.
    ///
    /// Focus should do nothing if the node `isDisabled` is true or if
    void focus();

    /// Returns: 
    ///     True if this node has focus. Recommended implementation: `return this == focusIO.focus`. 
    ///     Proxy nodes, such as `FieldSlot` might choose to return the value of the node they hold.
    bool isFocused() const;

}
