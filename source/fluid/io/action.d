/// This module contains interfaces for mapping input events to input actions.
module fluid.io.action;

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
/// `ActionIO` will work on nodes that are its children. That means that any input handling node must be placed
/// inside as a child will react to these actions. Similarly, nodes representing input devices, also have to be placed
/// as children.
interface ActionIO : IO {

    /// Basic input actions necessary for input actions to work.
    @InputAction
    enum CoreAction {

        /// This input action is fired in response to the `frame` input event.
        frame,

    }

    /// Create an input event to which `ActionIO` should always have bound to the `CoreAction.frame` input action. 
    /// Consequently, `ActionIO` always responds with a `CoreAction.frame` input action after processing remaining 
    /// input actions.
    ///
    /// This can be used by device and input handling I/Os to detect the moment after which all input actions have 
    /// been processed. This means that it can be used to develop fallback mechanisms like `hoverImpl` 
    /// and `focusImpl`, which only trigger if no input action has been activated.
    ///
    /// Note that `CoreAction.frame` might, or might not, be emitted if another action event has been emitted during
    /// the same frame. `InputMapSpace` will only emit `CoreAction.frame` is no other input action has been handled.
    static InputEvent frameEvent() {

        const code = InputEventCode(ioID!ActionIO, 1);
        const isActive = false;

        return InputEvent(code, isActive);

    }

    /// Pass an input event to transform into an input map.
    ///
    /// The `ActionIO` system should withhold all input actions until after its node is drawn. This is when
    /// all input handling nodes that the system interacts with, like `HoverIO` and `FocusIO`, have been processed
    /// and are ready to handle the event.
    ///
    /// Once processing has completed, if the event has triggered an action, the system will trigger the callback that 
    /// was passed along with the event. Events that were saved in the system should be discarded.
    ///
    /// Note if an event functions as a modifier — for example the "control" key in a "ctrl+c" action — it should not
    /// trigger the callback. In such case, only the last key, the "C" key in the example, will perform the call.
    /// This is to make sure the event is handled by the correct handler, and only once.
    ///
    /// Params:
    ///     event    = Input event the system should save.
    ///     number   = A number that will be passed as-is into the callback. Can be used to distinguish between
    ///         different action calls without allocating a closure.
    ///     callback = Function to call if the event has triggered an input action. 
    ///         The ID of the action will be passed as an argument, along with a boolean indicating if it was
    ///         triggered by an inactive, or active event.
    ///         The number passed into the `emitEvent` function will be passed as the third argument to this callback.
    ///         The return value of the callback should indicate if the action was handled or not.
    void emitEvent(InputEvent event, int number, 
        bool delegate(immutable InputActionID, bool isActive, int number) @safe callback);
    
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

/// Get the ID of an input action.
/// Params:
///     action = Action to get the ID of.
/// Returns:
///     `InputActionID` struct with the action encoded.
InputActionID inputActionID(alias action)() {

    return InputActionID.from!action;

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
    R resource = R.fetch(io, number);
    return handler(action, resource);
}

/// ditto
bool runInputActionHandler(T, R)(T action, IO io, int number, void delegate(T action, R resource) @safe handler)
if (isInputAction!action && isRetrievableResource!R) {
    R resource = R.fetch(io, number);
    handler(action, resource);
    return true;
}

/// ditto
bool runInputActionHandler(T, R)(T, IO io, int number, bool delegate(R resource) @safe handler)
if (isRetrievableResource!R) {
    if (io is null) {
        return false;
    }
    R resource = R.fetch(io, number);
    return handler(resource);
}

/// ditto
bool runInputActionHandler(T, R)(T, IO io, int number, void delegate(R resource) @safe handler)
if (isRetrievableResource!R) {
    if (io is null) {
        return false;
    }
    R resource = R.fetch(io, number);
    handler(resource);
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
                static if (isInputActionType!actionType) {

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