/// This module contains interfaces for mapping input events to input actions.
module fluid.io.action;

import optional;

import fluid.input;
import fluid.future.context;

public import fluid.input;

@safe:

/// I/O interface for mapping input events to input actions.
///
/// Input events correspond to direct events from input devices, like keyboard or mouse.
/// The job of `ActionIO` is to translate them into more meaningful input actions, which nodes
/// can set up listeners for.
///
/// `ActionIO` will work on nodes that are its children. That means that any input handling node
/// must be placed inside as a child will react to these actions. Similarly, nodes representing
/// input devices, also have to be placed as children.
///
/// `ActionIOv2` is currently recommended for new code, but more small updates are also expected
/// in short-term future.
///
/// History:
///     * [ActionIOv2] was added in Fluid 0.7.6 — it adds an [IO] parameter to [emitAction].
///     * `ActionIO` was introduced in Fluid 0.7.2.
interface ActionIOv1 : IO {

    /// Basic input actions necessary for input actions to work.
    @InputAction
    enum CoreAction {

        /// This input action is fired in response to the `frame` input event.
        frame,

    }

    enum Event {
        noopEvent,
        frameEvent,
    }

    /// Create an input event which should never activate any input action. For propagation
    /// purposes, this event always counts as handled.
    ///
    /// The usual purpose of this event is to prevent input actions from running, assuming
    /// the `ActionIO` system's logic stops once an event is handled. For example,
    /// `fluid.io.hover.HoverPointerAction` emits this event when it is ordered to run an input
    /// action, effectively overriding `ActionIO`'s response.
    ///
    /// See_Also:
    ///     `frameEvent`
    /// Params:
    ///     isActive = Should the input event be marked as active or not. Defaults to true.
    /// Returns:
    ///     An instance of `Event.noopEvent`.
    static InputEvent noopEvent(bool isActive = true) {

        const code = InputEventCode(ioID!ActionIO, Event.noopEvent);

        return InputEvent(code, isActive);

    }

    /// Create an input event to which `ActionIO` should always bind to the `CoreAction.frame` input action.
    /// Consequently, `ActionIO` always responds with a `CoreAction.frame` input action after processing remaining
    /// input actions. This can be cancelled by emitting a `noopEvent` before the `frameEvent` is handled.
    ///
    /// This can be used by device and input handling I/Os to detect the moment after which all input actions have
    /// been processed. This means that it can be used to develop fallback mechanisms like `hoverImpl`
    /// and `focusImpl`, which only trigger if no input action has been activated.
    ///
    /// Note that `CoreAction.frame` might, or might not, be emitted if another action event has been emitted during
    /// the same frame. `InputMapChain` will only emit `CoreAction.frame` is no other input action has been handled.
    ///
    /// See_Also:
    ///     `noopEvent`
    /// Returns:
    ///     An instance of `Event.frameEvent`.
    static InputEvent frameEvent() {

        const code = InputEventCode(ioID!ActionIO, Event.frameEvent);
        const isActive = false;

        return InputEvent(code, isActive);

    }

    /// Callback type for [emitEvent].
    alias ActionCallback = bool delegate(immutable InputActionID, bool isActive, int number) @safe;

    /// Pass an input event to transform into an input map.
    ///
    /// The `ActionIO` system should withhold all input actions until after its node is drawn.
    /// This is when all input handling nodes that the system interacts with, like `HoverIO` and
    /// `FocusIO`, have been processed and are ready to handle the event.
    ///
    /// Once processing has completed, if the event has triggered an action, the system will
    /// trigger the callback that was passed along with the event. Events that were saved in the
    /// system should be discarded.
    ///
    /// Note if an event functions as a modifier — for example the "control" key in a "ctrl+c"
    /// action — it should not trigger the callback. In such case, only the last key, the "C" key
    /// in the example, will perform the call. This is to make sure the event is handled by the
    /// correct handler, and only once.
    ///
    /// Params:
    ///     event    = Input event the system should save.
    ///     number   = A number that will be passed as-is into the callback. Can be used to
    ///         distinguish between different action calls without allocating a closure.
    ///     callback = Function to call if the event has triggered an input action. The ID of the
    ///         action will be passed as an argument, along with a boolean indicating if it was
    ///         triggered by an inactive, or active event. The number passed into the `emitEvent`
    ///         function will be passed as the third argument to this callback. The return value
    ///         of the callback should indicate if the action was handled or not.
    void emitEvent(InputEvent event, int number, ActionCallback callback);

}

///
interface ActionIO : ActionIOv1 {

    deprecated("Superseded by `ActionIOv2.emitEvent`. The original overload, and `ActionIOv1`, "
        ~ "will be removed in Fluid 0.8.0. To preserve backwards-compatibility, use "
        ~ "`Node.use(actionIOv1).upgrade(actionIOv2)`.")
    alias emitEvent = ActionIOv1.emitEvent;

}

/// An updated version of `ActionIO` that allows the event to be hijacked by an intermediate
/// `ActionIO` for introspection. This interface can be used to implement, for example, a fallback
/// handler for all input actions.
interface ActionIOv2 : ActionIO {

    /// An alternative overload for `ActionIO`, which accepts an `io` parameter.
    /// Params:
    ///     event    = Input event the system should save.
    ///     io       = I/O system that emitted the event. May be null.
    ///     number   = A number that will be passed as-is into the callback. Can be used to
    ///         distinguish between different action calls without allocating a closure.
    ///     callback = Function to call if the event has triggered an input action. The ID of the
    ///         action will be passed as an argument, along with a boolean indicating if it was
    ///         triggered by an inactive, or active event. The number passed into the `emitEvent`
    ///         function will be passed as the third argument to this callback. The return value
    ///         of the callback should indicate if the action was handled or not.
    void emitEvent(InputEvent event, IO io, int number, ActionCallback callback);

}

/// Uniquely codes a pressed key, button or a gesture, by using an I/O ID and event code map.
/// Each I/O interface can define its own keys and buttons it needs to map. The way it maps
/// codes to buttons is left up to the interface to define, but it usually is with an enum.
struct InputEventCode {

    /// ID for the I/O interface representing the input device. The I/O interface defines a code
    /// for each event it may send. This means the I/O ID along with the event code should uniquely identify events.
    ///
    /// An I/O system can create and emit events that belong to another system in order to simulate events
    /// from another device, however this scenario is likely better handled as a separate binding in `ActionIO`.
    IOID ioID;

    /// Event code identifying the key or button that triggered the event. These codes are defined
    /// by the I/O interface that send them.
    ///
    /// See_Also:
    ///     For keyboard codes, see `KeyboardIO`.
    ///     For mouse codes, see `MouseIO`.
    int event;

}

/// Represents an event coming from an input device, like a pressed key, button or a gesture.
///
/// This only covers events with binary outcomes: the source of event is active, or it is not.
/// Analog sources like joysticks may be translated into input events but they won't be precise.
struct InputEvent {

    /// Code uniquely identifying the source of the event, such as a key, button or gesture.
    InputEventCode code;

    /// Set to true if the event should trigger an input action.
    ///
    /// An input event should be emitted every frame the corresponding button or key is held down, but it will
    /// only be "active" for one of the frames. The one active frame determines when input actions that derive
    /// from the event will be fired.
    ///
    /// For a keyboard key, this will be the first frame the key is held (when it is pressed). For a mouse button,
    /// this will be the last frame (when it is released).
    bool isActive;

}

/// This is a base interface for nodes that respond to input actions. While `ActionIO` shouldn't interact
/// with nodes directly, input handling systems like `FocusIO` or `HoverIO` will expect nodes to implement
/// this interface if they support input actions.
interface Actionable {

    /// Determine if the node can currently handle input.
    ///
    /// Blocking input changes behavior of I/O systems responsible for passing the node input data:
    ///
    /// * A blocked node should NOT have input events called. It is illegal to call `actionImpl`. Input method
    ///   and device-specific handlers like `hoverImpl` and `focusImpl` usually won't be called either.
    /// * If the input method has a node selection method like focus or hover, nodes that block input should be
    ///   excluded from selection. If a node starts blocking while already selected may continue to be selected.
    ///
    /// Returns:
    ///     True if the node "blocks" input — it cannot accept input events, nor focus.
    ///     False if the node accepts input, and operates like normal.
    bool blocksInput() const;

    /// Handle an input action.
    ///
    /// This method should not be called for nodes for which `blocksInput` is true.
    ///
    /// Params:
    ///     io       = I/O input handling system to trigger the action, for example `HoverIO` or `FocusIO`.
    ///         May be null.
    ///     number   = Number assigned by the I/O system. May be used to fetch a resource from the I/O system if it
    ///         supported.
    ///     action   = ID of the action to handle.
    ///     isActive = If true, this is an active action.
    ///         Most event handlers is only interested in active handlers;
    ///         they indicate the event has changed state (just pressed, or just released),
    ///         whereas an inactive action merely means the button or key is down.
    /// Returns:
    ///     True if the action was handled, false if not.
    bool actionImpl(IO io, int number, immutable InputActionID action, bool isActive)
    in (!blocksInput, "This node currently doesn't accept input.");

    /// A shortcut for invoking specific input actions from code.
    /// Params:
    ///     action   = Input action to invoke; an `@InputAction` enum member.
    ///     isActive = Whether to start an active or "held" input action.
    /// Returns:
    ///     True if the node handled the action.
    final bool runInputAction(alias action)(bool isActive = true) {
        return actionImpl(null, 0, inputActionID!action, isActive);
    }

    /// Memory safe and `const` object comparison.
    /// Returns:
    ///     True if this, and the other object, are the same object.
    /// Params:
    ///     other = Object to compare to.
    bool opEquals(const Object other) const;

    mixin template enableInputActions() {

        import fluid.future.context : IO;
        import fluid.io.action : InputActionID;

        override bool actionImpl(IO io, int number, immutable InputActionID action, bool isActive) {

            import fluid.io.action : runInputActionHandler;

            return runInputActionHandler(this, io, number, action, isActive);

        }

    }

}

/// Template with a set of functions for creating input event and input event codes
/// from an enum. It can be used as a `mixin` in device nodes; see `MouseIO` and `KeyboardIO`
/// for sample usage.
template inputEvents(LocalIO, Event)
if (is(LocalIO : IO) && is(Event == enum)) {

    /// Get the input event code from an enum member.
    /// Params:
    ///     event = Code for this event.
    /// Returns:
    ///     Input event code that can be used for input event routines.
    static InputEventCode getCode(Event event) {
        return InputEventCode(ioID!LocalIO, event);
    }

    /// A shortcut for getting input event codes that are known at compile time. Handy for
    /// tests.
    /// Returns: A struct with event code for each member, corresponding to members of
    /// `Button`.
    static codes() {
        static struct Codes {
            InputEventCode opDispatch(string name)() {
                return getCode(__traits(getMember, Event, name));
            }
        }
        return Codes();
    }

    /// Create a mouse input event that can be passed to an `ActionIO` handler.
    ///
    /// Params:
    ///     event    = Event type.
    ///     isActive = True if the event is "active" and should trigger input actions.
    /// Returns:
    ///     The created input event.
    static InputEvent createEvent(Event event, bool isActive = true) {
        const code = getCode(event);
        return InputEvent(code, isActive);
    }

    /// A shortcut for getting input events that are known at compile time. Handy for tests.
    /// Params:
    ///     isActive = True if the generated input event should be active. Defaults to `false`
    ///         for `hold`; is `true` for `click`.
    /// Returns: A mouse button input event.
    static click() {
        return hold(true);
    }

    /// ditto
    static hold(bool isActive = false) {
        static struct Codes {
            bool isActive;
            InputEvent opDispatch(string name)() {
                return createEvent(
                    __traits(getMember, Event, name),
                    isActive);
            }
        }
        return Codes(isActive);
    }

}

/// Cast the node to given type if it accepts input using the given method.
///
/// In addition to performing a dynamic cast, this checks if the node currently accepts input.
/// If it doesn't (for example, if the node is disabled), it will fail the cast.
///
/// Params:
///     node = Node to cast.
/// Returns:
///     Node casted to the given type, or null if the node can't be casted, or it doesn't support given input method.
inout(T) castIfAcceptsInput(T : Actionable)(inout Object node) {

    // Perform the cast
    if (auto actionable = cast(inout T) node) {

        // Fail if the node blocks input
        if (actionable.blocksInput) {
            return null;
        }

        return actionable;

    }

    return null;

}

/// Check if the given symbol defines an input action.
///
/// The symbol symbol must be a member of an enum marked with `@InputAction`. The enum $(B must not) be a manifest
/// constant (eg. `enum foo = 123;`).
template isInputAction(alias action) {

    // Require the action type to be an enum
    static if (is(typeof(action) == enum)) {

        // Search through the enum's attributes
        static foreach (attribute; __traits(getAttributes, typeof(action))) {

            // Not yet found
            static if (!is(typeof(isInputAction) == bool)) {

                // Check if this is the attribute we're looking for
                static if (__traits(isSame, attribute, InputAction)) {

                    enum isInputAction = true;

                }

            }

        }

    }

    // Not found
    static if (!is(typeof(isInputAction) == bool)) {

        // Respond as false
        enum isInputAction = false;

    }

}

enum isRetrievableResource(T) = __traits(compiles, T.fetch(IO.init, 0));

/// Helper function to run an input action handler through one of the possible overloads.
///
/// Params:
///     action  = Evaluated input action type.
///         Presently, this is an enum member of the input action it comes from.
///         `InputActionID` cannot be used here.
///     handler = Handler for the action.
///         The handler may choose to return a boolean,
///         indicating if it handled (true) or ignored the action (false).
///
///         It may also optionally accept the input action enum, for example `FluidInputAction`,
///         if all of its events are bound to its members (like `FluidInputAction.press`).
/// Returns:
///     True if the handler responded to this action, false if not.
bool runInputActionHandler(T)(T action, bool delegate(T action) @safe handler)
if (isInputAction!action) {
    return handler(action);
}

/// ditto
bool runInputActionHandler(T)(T action, void delegate(T action) @safe handler)
if (isInputAction!action) {
    handler(action);
    return true;
}

/// ditto
bool runInputActionHandler(T)(T, bool delegate() @safe handler) {
    return handler();
}

/// ditto
bool runInputActionHandler(T)(T, void delegate() @safe handler) {
    handler();
    return true;
}

/// Uniform wrapper over the varied set of input action handler variants.
///
/// This is an alternative, newer set of overloads for handling input actions with support for passing event metadata
/// through resources.
///
/// Params:
///     action  = Evaluated input action type.
///         Presently, this is an enum member of the input action it comes from.
///         `InputActionID` cannot be used here.
///     handler = Handler for the action.
///         The handler may choose to return a boolean,
///         indicating if it handled (true) or ignored the action (false).
///
///         It may also optionally accept the input action enum, for example `FluidInputAction`,
///         if all of its events are bound to its members (like `FluidInputAction.press`).
///
///         It may accept a resource type if the resource has a `static fetch(IO, int)` method.
/// Returns:
///     True if the handler responded to this action, false if not.
bool runInputActionHandler(T, R)(T action, IO io, int number, bool delegate(T action, R resource) @safe handler)
if (isInputAction!action && isRetrievableResource!R) {
    if (io is null) {
        return false;
    }
    Optional!R resource = R.fetch(io, number);
    if (resource.empty) {
        return false;
    }
    return handler(action, resource.front);
}

/// ditto
bool runInputActionHandler(T, R)(T action, IO io, int number, void delegate(T action, R resource) @safe handler)
if (isInputAction!action && isRetrievableResource!R) {
    if (io is null) {
        return false;
    }
    Optional!R resource = R.fetch(io, number);
    if (resource.empty) {
        return false;
    }
    handler(action, resource.front);
    return true;
}

/// ditto
bool runInputActionHandler(T, R)(T, IO io, int number, bool delegate(R resource) @safe handler)
if (isRetrievableResource!R) {
    if (io is null) {
        return false;
    }
    Optional!R resource = R.fetch(io, number);
    if (resource.empty) {
        return false;
    }
    return handler(resource.front);
}

/// ditto
bool runInputActionHandler(T, R)(T, IO io, int number, void delegate(R resource) @safe handler)
if (isRetrievableResource!R) {
    if (io is null) {
        return false;
    }
    Optional!R resource = R.fetch(io, number);
    if (resource.empty) {
        return false;
    }
    handler(resource.front);
    return true;
}

/// ditto
bool runInputActionHandler(T)(T action, IO, int, bool delegate(T action) @safe handler)
if (isInputAction!action) {
    return handler(action);
}

/// ditto
bool runInputActionHandler(T)(T action, IO, int, void delegate(T action) @safe handler)
if (isInputAction!action) {
    handler(action);
    return true;
}

/// ditto
bool runInputActionHandler(T)(T, IO, int, bool delegate() @safe handler) {
    return handler();
}

/// ditto
bool runInputActionHandler(T)(T, IO, int, void delegate() @safe handler) {
    handler();
    return true;
}

/// Run a handler for an input action.
/// Params:
///     aggregate = Struct or class with input action handlers.
///     actionID  = ID of the action to run.
///     isActive  = True, if the action has fired, false if it is held.
/// Returns:
///     True if there exists a matching input handler, and if it responded
///     to the input action.
bool runInputActionHandler(T)(auto ref T aggregate, immutable InputActionID actionID, bool isActive = true) {

    return runInputActionHandler(aggregate, null, 0, actionID, isActive);

}

/// Run a handler for an input action.
///
/// This is a newer, alternative overload
///
/// Params:
///     aggregate = Struct or class with input action handlers.
///     io        = I/O system to emit the action.
///     number    = Number internal to the I/O syste; may be used to fetch additional data.
///     actionID  = ID of the action to run.
///     isActive  = True, if the action has fired, false if it is held.
/// Returns:
///     True if there exists a matching input handler, and if it responded
///     to the input action.
bool runInputActionHandler(T)(auto ref T aggregate, IO io, int number,
    immutable InputActionID actionID, bool isActive = true)
do {

    import std.functional : toDelegate;

    bool handled;

    // Check every action
    static foreach (handler; InputActionHandlers!T) {

        // Run handlers that handle this action
        if (handler.inputActionID == actionID) {

            // Run the action if the stroke was performed
            if (shouldActivateWhileDown!(handler.method) || isActive) {

                auto dg = toDelegate(&__traits(child, aggregate, handler.method));

                handled = runInputActionHandler(handler.inputAction, io, number, dg) || handled;
                // TODO 0.8.0 abandon

            }

        }

    }

    return handled;

}

/// Wraps an input action handler.
struct InputActionHandler(alias action, alias actionHandler) {

    /// Symbol handling the action.
    alias method = actionHandler;

    /// Type of the handler.
    alias inputAction = action;

    static InputActionID inputActionID() {

        return .inputActionID!action;

    }

}

/// Find every input action handler in the given type, and check which input actions it handles.
///
/// For every such input handler, this will create an `InputActionHandler` struct.
template InputActionHandlers(T) {

    import std.meta;

    alias Result = AliasSeq!();

    // Check each member
    static foreach (memberName; __traits(allMembers, T)) {

        static if (!__traits(isDeprecated, __traits(getMember, T, memberName)))
        static foreach (overload; __traits(getOverloads, T, memberName)) {

            // Find the matching action
            static foreach (i, actionType; __traits(getAttributes, overload)) {

                // Input action — add to the result
                static if (isInputAction!actionType) {

                    Result = AliasSeq!(
                        Result,
                        InputActionHandler!(__traits(getAttributes, overload)[i], overload)
                    );

                }

                // Prevent usage via @InputAction
                else static if (is(typeof(actionType)) && isInstanceOf!(typeof(actionType), InputAction)) {

                    static assert(false,
                        format!"Please use @(%s) instead of @InputAction!(%1$s)"(actionType.type));

                }

            }

        }

    }

    alias InputActionHandlers = Result;

}
