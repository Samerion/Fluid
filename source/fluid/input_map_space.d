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
        int number;
        bool delegate(InputActionID action, bool isActive, int number) @safe callback;
    }

    public {

        /// Map of input events to input actions.
        InputMapping map;

    }

    private {

        /// All collected input events.
        Stack!ReceivedInputEvent _events;

    }

    this(InputMapping map, Node[] nodes...) {
        super(nodes);
        this.map = map;
    }

    override void resizeImpl(Vector2 space) {

        auto frame = this.implementIO();
        super.resizeImpl(space);

    }

    override void drawImpl(Rectangle outer, Rectangle inner) {

        super.drawImpl(outer, inner);

        // Process all input events
        processEvents();
        _events.clear();

    }

    override void emitEvent(InputEvent event, int number, 
        bool delegate(InputActionID action, bool isActive, int number) @safe callback)
    do {

        // Save the event to list
        _events ~= ReceivedInputEvent(event, number, callback);

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

        return _events[].filter!(a => a.event.code == code);

    }

    /// Detect all input actions that should be emitted as a consequence of the events that occured this frame.
    /// Clears the current list of events when done.
    private void processEvents() @trusted {

        scope (exit) _events.clear();

        bool handled;

        // Test all mappings
        foreach (layer; map.layers) {

            // Check if every modifier in this layer is active
            if (layer.modifiers.any!(a => findEvents(a).empty)) continue;

            // Found an active layer, test all bound strokes
            foreach (binding; layer.bindings) {

                // Check if any of the events matches this binding
                foreach (event; findEvents(binding.code)) {

                    handled = handled || event.callback(binding.inputAction, event.event.isActive, event.number);

                }

                // Stroke handled, stop here
                if (handled) break;

            }

            // End on this layer
            break;

        }

        // No event was handled, fire the frame event
        if (!handled) {

            foreach (event; findEvents(frameEvent.code)) {
                event.callback(inputActionID!(CoreAction.frame), event.event.isActive, event.number);
            }

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

    /// Bind an input stroke to an input action.
    ///
    /// Does not replace any existing mappings, even in case of collision. Previously created mappings will 
    /// have higher higher priority than this mapping.
    ///
    /// Params:
    ///     action = Input action the stroke should trigger
    ///     codes  = Sequence of event codes that triggers the event.
    void bindNew(InputActionID action, InputEventCode[] codes...)
    in (codes.length >= 1)
    do {

        auto  modifiers = codes[0 .. $-1].dup;
        const trigger   = codes[$-1];
        const binding   = Trigger(action, trigger);

        // Find a matching layer for this mapping
        foreach (i, ref layer; layers) {

            if (layer.modifiers.length > modifiers.length) continue;

            // No layer has this set of modifiers
            if (layer.modifiers.length < modifiers.length) {

                // Create one
                auto newLayer = Layer(modifiers, [binding]);

                // Insert
                layers = layers[0..i] ~ newLayer ~ layers[i..$];
                return;

            }

            // Found a matching layer
            if (layer.modifiers == modifiers) {

                // Insert the binding
                layer.bindings ~= binding;
                return;

            }

        }

        // This has less modifiers than any existing layer
        layers ~= Layer(modifiers, [binding]);

    }

    /// ditto
    void bindNew(alias action)(InputEventCode[] codes...) {

        const actionID = inputActionID!action;
        bindNew(actionID, codes);

    }

    /// Add a number of bindings to an empty map.
    unittest {

        import fluid.io.keyboard;

        auto map = InputMapping();
        map.bindNew!(FluidInputAction.press)    (KeyboardIO.codes.enter);
        map.bindNew!(FluidInputAction.focusNext)(KeyboardIO.codes.tab);
        map.bindNew!(FluidInputAction.submit)   (KeyboardIO.codes.leftControl, KeyboardIO.codes.enter);
        map.bindNew!(FluidInputAction.copy)     (KeyboardIO.codes.leftControl, KeyboardIO.codes.c);

        // The above creates equivalent layers
        assert(map.layers == [
            Layer([KeyboardIO.codes.leftControl], [
                Trigger(inputActionID!(FluidInputAction.submit), KeyboardIO.codes.enter),
                Trigger(inputActionID!(FluidInputAction.copy),   KeyboardIO.codes.c),
            ]),
            Layer([], [
                Trigger(inputActionID!(FluidInputAction.press),     KeyboardIO.codes.enter),
                Trigger(inputActionID!(FluidInputAction.focusNext), KeyboardIO.codes.tab),
            ]),
        ]);

    }

}
