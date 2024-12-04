module fluid.input_map_space;

import std.algorithm;

import fluid.node;
import fluid.space;
import fluid.utils;
import fluid.input;
import fluid.types;

import fluid.io.action;

import fluid.future.stack;

@safe:

alias inputMapSpace = nodeBuilder!InputMapSpace;

class InputMapSpace : Space, ActionIO {

    private struct ReceivedInputEvent {
        InputEvent event;
        bool delegate(InputActionID action, bool isActive) @safe callback;
    }

    public {

        /// Map of input events to input actions.
        InputMapping map;

    }

    private {

        /// All collected input events.
        Stack!ReceivedInputEvent events;

    }

    this(Node[] nodes...) {
        super(nodes);
    }

    override void drawImpl(Rectangle outer, Rectangle inner) {

        super.drawImpl(outer, inner);

        // Process all input events
        processEvents();
        events.clear();

    }

    override void emitEvent(InputEvent event, bool delegate(InputActionID action, bool isActive) @safe callback) {

        // Save the event to list
        events ~= ReceivedInputEvent(event, callback);

    }

    /// Find the given event type among ones that were emitted this frame.
    /// Safety:
    ///     The range has to be exhaused immediately. 
    ///     No input events can be emitted before the range is disposed of, or the range will break.
    /// Params:
    ///     code = Input event code to find.
    /// Returns:
    ///     A range with all emitted events that match the query.
    auto findEvents(InputEventCode code) @system {

        return events[].filter!(a => a.event.code == code);

    }

    /// Detect all input actions that should be emitted as a consequence of the events that occured this frame.
    /// Clears the current list of events when done.
    private void processEvents() @trusted {

        scope (exit) events.clear();

        // Test all mappings
        foreach (layer; map.layers) {

            // Check if every modifier in this layer is active
            if (layer.modifiers.any!(a => findEvents(a).empty)) continue;

            // Found an active layer, test all bound strokes
            foreach (binding; layer.bindings) {

                bool handled;

                // Check if any of the events matches this binding
                foreach (event; findEvents(binding.code)) {

                    handled = handled || event.callback(binding.inputAction, event.event.isActive);

                }

                // Stroke handled, stop here
                if (handled) break;

            }

            // End on this layer
            break;

        }

    }

}

/// Maps sequences input events to input actions.
/// 
/// Actions are bound to "strokes". A single stroke is a set of modifier events and a trigger event. 
/// A stroke without modifiers is one that directly binds a button or key to an action, for example
/// mapping the backspace key to an "eraseCharacter" action. Modifiers can be added to require that
/// multiple other buttons be held for the action to work — the "ctrl+C" stroke, often used to copy
/// text, has one modifier key "ctrl" and a trigger key "c".
///
/// Mappings are grouped by modifiers into "layers". All mappings that share the same set of modifiers
/// will be placed on the same layer. These layers are sorted by number of modifiers, and only one is 
/// looked up at once; this prevents firing an action with a less complex set of modifiers from 
/// accidentally firing when performing a more complex one. For example, an action bound to the key "C"
/// will not fire when pressing "ctrl+C".
///
/// Mappings can combine multiple input events, so it is possible to use both keyboard keys and mouse
/// buttons in a mapping. A mouse button could be used as a trigger, combined with a keyboard key as
/// a modifier, such as "ctrl + left mouse button".
struct InputMapping {

    /// Final element in a stroke, completing the circuit and creating the event.
    struct Trigger {

        /// Input action that should be emitted.
        InputActionID inputAction;

        /// Event code that triggers this action.
        InputEventCode code;
    }

    /// A layer groups all mappings that share the same set of input event codes.
    struct Layer {

        /// Modiifers that have to be pressed for this layer to be checked.
        InputEventCode[] modifiers;

        /// Keys and events on this layer.
        Trigger[] bindings;

        int opCmp(const Layer other) const {

            // You're not going to put 2,147,483,646 modifiers in a single stroke, are you?
            return cast(int) (other.modifiers.length - modifiers.length);

        }

    }

    /// All input layers that have been mapped.
    ///
    /// Input layers have to be sorted, so that the layer with most modifiers have to be first, and layer with no
    /// modifiers have to be last. Every layer should have a unique set of modifiers.
    Layer[] layers;

    invariant(layers.isSorted);

}
