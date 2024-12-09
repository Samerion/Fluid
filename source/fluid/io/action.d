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
    ///     callback = Function to call if the event has triggered an input action. 
    ///         The ID of the action will be passed as an argument, along with a boolean indicating if it was
    ///         triggered by an inactive, or active event.
    ///         The return value of the callback should indicate if the action was handled or not.
    void emitEvent(InputEvent event, bool delegate(immutable InputActionID, bool isActive) @safe callback);
    
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

    /// Handle an input action.
    /// Params:
    ///     action   = ID of the action to handle.
    ///     isActive = If true, this is an active action.
    ///         Most event handlers is only interested in active handlers; 
    ///         they indicate the event has changed state (just pressed, or just released), 
    ///         whereas an inactive action merely means the button or key is down.
    /// Returns:
    ///     True if the action was handled, false if not.
    bool actionImpl(InputActionID action, bool isActive);

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
bool runInputActionHandler(T)(T action, bool delegate(T action) @safe handler) {
    return handler(action);
}

/// ditto
bool runInputActionHandler(T)(T action, void delegate(T action) @safe handler) {
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

/// Run a handler for an input action.
/// Params:
///     aggregate = Struct or class with input action handlers.
///     actionID  = ID of the action to run.
///     isActive  = True, if the action has fired, false if it is held.
/// Returns:
///     True if there exists a matching input handler, and if it responded
///     to the input action.
bool runInputActionHandler(T)(auto ref T aggregate, immutable InputActionID actionID, bool isActive = true) {

    bool handled;

    // Check every action
    static foreach (handler; InputActionHandlers!T) {

        // Run handlers that handle this action
        if (handler.inputActionID == actionID) {

            // Run the action if the stroke was performed
            if (shouldActivateWhileDown!(handler.method) || isActive) {

                handled = runInputActionHandler(handler.inputAction,
                    &__traits(child, aggregate, handler.method)) || handled;

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
