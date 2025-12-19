module fluid.input_map_chain;

import std.array;
import std.algorithm;

import fluid.node;
import fluid.utils;
import fluid.input;
import fluid.types;
import fluid.node_chain;

import fluid.io.action;

@safe:

alias inputMapChain  = nodeBuilder!InputMapChain;

class InputMapChain : NodeChain, ActionIOv2 {

    mixin controlIO;

    private struct ReceivedInputEvent {
        InputEvent event;
        int number;
        ActionCallback callback;
    }

    public {

        /// Map of input events to input actions.
        InputMapping map;

    }

    private {

        /// All collected input events.
        Appender!(ReceivedInputEvent[]) _events;

    }

    this(InputMapping map, Node next = null) {
        super(next);
        this.map = map;
    }

    this(Node next = null) {
        this(InputMapping.defaultMapping, next);
    }

    override void beforeResize(Vector2) {
        startIO();
    }

    override void afterResize(Vector2) {
        stopIO();
    }

    override void afterDraw(Rectangle, Rectangle) {

        // Process all input events
        processEvents();
        _events.clear();

    }

    override void emitEvent(InputEvent event, IO io, int number, ActionCallback callback) {
        _events ~= ReceivedInputEvent(event, number, callback);
    }

    /// Find the given event type among ones that were emitted this frame.
    /// Safety:
    ///     The range has to be exhausted immediately.
    ///     No input events can be emitted before the range is disposed of, or the range will break.
    /// Params:
    ///     code = Input event code to find.
    /// Returns:
    ///     A range with all emitted events that match the query.
    auto findEvents(InputEventCode code) @system {

        return _events[].filter!(a => a.event.code == code);

    }

    /// Detect all input actions that should be emitted as a consequence of the events that occurred this frame.
    /// Clears the current list of events when done.
    private void processEvents() @trusted {

        scope (exit) _events.clear();

        bool handled;

        // Test noop event first
        foreach (event; findEvents(noopEvent.code)) {
            return;
        }

        // Test all mappings
        foreach (layer; map.layers) {

            // Check if every modifier in this layer is active
            if (layer.modifiers.any!(a => findEvents(a).empty)) continue;

            // Found an active layer, test all bound strokes
            foreach_reverse (binding; layer.bindings) {

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

        /// Modifiers that have to be pressed for this layer to be checked.
        InputEventCode[] modifiers;

        /// Keys and events on this layer. These binding are tested in reverse-order,
        /// so bindings that come last are tested first, giving them higher priority.
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

    /// Create a default input map using commonly used input sequences for each of the default actions.
    /// Returns:
    ///     A newly created input mapping.
    static InputMapping defaultMapping() {

        import fluid.io.keyboard;
        import fluid.io.mouse;

        InputMapping mapping;

        /// Get the ID of an input action.
        auto bind(alias a)(InputEventCode code) {
            return Trigger(inputActionID!a, code);
        }

        with (FluidInputAction) {

            // System-independent keys
            auto universalShift = Layer(
                [KeyboardIO.codes.leftShift],
                [
                    bind!focusPrevious(KeyboardIO.codes.tab),
                    bind!contextMenu(KeyboardIO.codes.f10),
                    bind!breakLine(KeyboardIO.codes.enter),
                    bind!selectToLineEnd(KeyboardIO.codes.end),
                    bind!selectToLineStart(KeyboardIO.codes.home),
                    bind!selectNextLine(KeyboardIO.codes.down),
                    bind!selectPreviousLine(KeyboardIO.codes.up),
                    bind!selectNextChar(KeyboardIO.codes.right),
                    bind!selectPreviousChar(KeyboardIO.codes.left),
                    bind!outdent(KeyboardIO.codes.tab),
                    bind!entryPrevious(KeyboardIO.codes.tab),
                ]
            );
            auto universal = Layer(
                [],
                [
                    // Focus control
                    // bind!focusDown(GamepadButton.dpadDown), TODO
                    bind!focusDown(KeyboardIO.codes.down),
                    // bind!focusUp(GamepadButton.dpadUp), TODO
                    bind!focusUp(KeyboardIO.codes.up),
                    // bind!focusRight(GamepadButton.dpadRight), TODO
                    bind!focusRight(KeyboardIO.codes.right),
                    // bind!focusLeft(GamepadButton.dpadLeft), TODO
                    bind!focusLeft(KeyboardIO.codes.left),
                    // bind!focusNext(GamepadButton.rightButton), TODO
                    bind!focusNext(KeyboardIO.codes.tab),
                    // bind!focusPrevious(GamepadButton.leftButton), TODO

                    // Scroll
                    bind!pageDown(KeyboardIO.codes.pageDown),
                    bind!pageUp(KeyboardIO.codes.pageUp),
                    // bind!scrollDown(GamepadButton.dpadDown), TODO
                    bind!scrollDown(KeyboardIO.codes.down),
                    // bind!scrollUp(GamepadButton.dpadUp), TODO
                    bind!scrollUp(KeyboardIO.codes.up),
                    // bind!scrollRight(GamepadButton.dpadRight), TODO
                    bind!scrollRight(KeyboardIO.codes.right),
                    // bind!scrollLeft(GamepadButton.dpadLeft), TODO
                    bind!scrollLeft(KeyboardIO.codes.left),
                    // bind!submit(GamepadButton.cross), TODO

                    // Submit
                    bind!submit(KeyboardIO.codes.enter),

                    // Text editing
                    bind!insertTab(KeyboardIO.codes.tab),
                    bind!toLineEnd(KeyboardIO.codes.end),
                    bind!toLineStart(KeyboardIO.codes.home),
                    // bind!entryNext(GamepadButton.dpadDown), TODO
                    bind!entryNext(KeyboardIO.codes.tab),
                    bind!entryNext(KeyboardIO.codes.down),
                    // bind!entryPrevious(GamepadButton.dpadUp), TODO
                    bind!entryPrevious(KeyboardIO.codes.up),
                    bind!nextLine(KeyboardIO.codes.down),
                    bind!previousLine(KeyboardIO.codes.up),
                    bind!nextChar(KeyboardIO.codes.right),
                    bind!previousChar(KeyboardIO.codes.left),
                    bind!breakLine(KeyboardIO.codes.enter),
                    bind!deleteChar(KeyboardIO.codes.delete_),
                    bind!backspace(KeyboardIO.codes.backspace),

                    // Basic actions
                    // bind!cancel(GamepadButton.circle), TODO
                    bind!cancel(KeyboardIO.codes.escape),
                    bind!cancel(KeyboardIO.codes.right),
                    bind!contextMenu(KeyboardIO.codes.contextMenu),
                    bind!contextMenu(MouseIO.codes.right),
                    // bind!press(GamepadButton.cross), TODO
                    bind!press(KeyboardIO.codes.enter),
                    bind!press(MouseIO.codes.left),
                ]
            );

            // TODO universal left/right key
            version (Fluid_MacKeyboard)
                mapping.layers = [

                    // Shift + Command
                    Layer(
                        [KeyboardIO.codes.leftShift, KeyboardIO.codes.leftSuper],
                        [
                            // TODO Command should *expand selection* on macOS instead of current
                            // toLineStart/toLineEnd behavior
                            bind!redo(KeyboardIO.codes.z),
                            bind!selectToEnd(KeyboardIO.codes.down),
                            bind!selectToStart(KeyboardIO.codes.up),
                            bind!selectToLineEnd(KeyboardIO.codes.right),
                            bind!selectToLineStart(KeyboardIO.codes.left),
                        ]
                    ),

                    // Shift + Option
                    Layer(
                        [KeyboardIO.codes.leftShift, KeyboardIO.codes.leftAlt],
                        [
                            bind!selectNextWord(KeyboardIO.codes.right),
                            bind!selectPreviousWord(KeyboardIO.codes.left),
                        ]
                    ),

                    // Command
                    Layer(
                        [KeyboardIO.codes.leftSuper],
                        [
                            bind!submit(KeyboardIO.codes.enter),
                            bind!redo(KeyboardIO.codes.y),
                            bind!undo(KeyboardIO.codes.z),
                            bind!paste(KeyboardIO.codes.v),
                            bind!cut(KeyboardIO.codes.x),
                            bind!copy(KeyboardIO.codes.c),
                            bind!selectAll(KeyboardIO.codes.a),
                            bind!toEnd(KeyboardIO.codes.down),
                            bind!toStart(KeyboardIO.codes.up),
                            bind!toLineEnd(KeyboardIO.codes.right),
                            bind!toLineStart(KeyboardIO.codes.left),
                        ]
                    ),

                    // Option
                    Layer(
                        [KeyboardIO.codes.leftAlt],
                        [
                            bind!nextWord(KeyboardIO.codes.right),
                            bind!previousWord(KeyboardIO.codes.left),
                            bind!backspaceWord(KeyboardIO.codes.backspace),
                            bind!deleteWord(KeyboardIO.codes.delete_),
                        ]
                    ),

                    // Control
                    Layer(
                        [KeyboardIO.codes.leftControl],
                        [
                            bind!entryNext(KeyboardIO.codes.n),  // emacs
                            bind!entryNext(KeyboardIO.codes.j),  // vim
                            bind!entryPrevious(KeyboardIO.codes.p),  // emacs
                            bind!entryPrevious(KeyboardIO.codes.k),  // vim
                            bind!backspaceWord(KeyboardIO.codes.w),  // emacs & vim
                        ]
                    ),

                    universalShift,
                    universal,
                ];
            else
                mapping.layers = [

                    Layer(
                        [KeyboardIO.codes.leftShift, KeyboardIO.codes.leftControl],
                        [
                            bind!redo(KeyboardIO.codes.z),
                            bind!selectToEnd(KeyboardIO.codes.end),
                            bind!selectToStart(KeyboardIO.codes.home),
                            bind!selectNextWord(KeyboardIO.codes.right),
                            bind!selectPreviousWord(KeyboardIO.codes.left),
                        ]
                    ),

                    Layer(
                        [KeyboardIO.codes.leftControl],
                        [
                            bind!submit(KeyboardIO.codes.enter),
                            bind!toEnd(KeyboardIO.codes.end),
                            bind!toStart(KeyboardIO.codes.home),
                            bind!redo(KeyboardIO.codes.y),
                            bind!undo(KeyboardIO.codes.z),
                            bind!paste(KeyboardIO.codes.v),
                            bind!cut(KeyboardIO.codes.x),
                            bind!copy(KeyboardIO.codes.c),
                            bind!selectAll(KeyboardIO.codes.a),
                            bind!nextWord(KeyboardIO.codes.right),
                            bind!previousWord(KeyboardIO.codes.left),
                            bind!entryNext(KeyboardIO.codes.n),  // emacs
                            bind!entryNext(KeyboardIO.codes.j),  // vim
                            bind!entryPrevious(KeyboardIO.codes.p),  // emacs
                            bind!entryPrevious(KeyboardIO.codes.k),  // vim
                            bind!backspaceWord(KeyboardIO.codes.w),  // emacs & vim
                            bind!backspaceWord(KeyboardIO.codes.backspace),
                            bind!deleteWord(KeyboardIO.codes.delete_),
                        ]
                    ),

                    Layer(
                        [KeyboardIO.codes.leftAlt],
                        [
                            bind!contextMenu(KeyboardIO.codes.f10),
                            bind!entryUp(KeyboardIO.codes.up),
                        ]
                    ),

                    universalShift,
                    universal,

                ];

        }

        return mapping;

    }

}
