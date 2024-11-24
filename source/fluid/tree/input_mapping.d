/// This module handles mapping input events to input actions.
module fluid.tree.input_mapping;

import std.algorithm;

import fluid.backend;

@safe:

/// Represents a key or button input combination.
struct InputStroke {

    // TODO remove std.sumtype
    import std.sumtype;

    alias Item = SumType!(KeyboardKey, MouseButton, GamepadButton);

    Item[] input;

    this(T...)(T items)
    if (!is(items : Item[])) {

        input.length = items.length;
        static foreach (i, item; items) {

            input[i] = Item(item);

        }

    }

    this(Item[] items) {

        input = items;

    }

    /// Get number of items in the stroke.
    size_t length() const {
        return input.length;
    }

    /// Get a copy of the input stroke with the last item removed, if any.
    ///
    /// For example, for a `leftShift+w` stroke, this will return `leftShift`.
    InputStroke modifiers() {

        return input.length
            ? InputStroke(input[0..$-1])
            : InputStroke();

    }

    /// Check if the last item of this input stroke is done with a mouse
    bool isMouseStroke() const {

        return isMouseItem(input[$-1]);

    }

    unittest {

        assert(!InputStroke(KeyboardKey.leftControl).isMouseStroke);
        assert(!InputStroke(KeyboardKey.w).isMouseStroke);
        assert(!InputStroke(KeyboardKey.leftControl, KeyboardKey.w).isMouseStroke);

        assert(InputStroke(MouseButton.left).isMouseStroke);
        assert(InputStroke(KeyboardKey.leftControl, MouseButton.left).isMouseStroke);

        assert(!InputStroke(GamepadButton.triangle).isMouseStroke);
        assert(!InputStroke(KeyboardKey.leftControl, GamepadButton.triangle).isMouseStroke);

    }

    /// Check if the given item is done with a mouse.
    static bool isMouseItem(Item item) {

        return item.match!(
            (MouseButton _) => true,
            (_) => false,
        );

    }

    /// Check if all keys or buttons required for the stroke are held down.
    bool isDown(const FluidBackend backend) const {

        return input.all!(a => isItemDown(backend, a));

    }

    ///
    unittest {

        auto stroke = InputStroke(KeyboardKey.leftControl, KeyboardKey.w);
        auto io = new HeadlessBackend;

        // No keys pressed
        assert(!stroke.isDown(io));

        // Control pressed
        io.press(KeyboardKey.leftControl);
        assert(!stroke.isDown(io));

        // Both keys pressed
        io.press(KeyboardKey.w);
        assert(stroke.isDown(io));

        // Still pressed, but not immediately
        io.nextFrame;
        assert(stroke.isDown(io));

        // W pressed
        io.release(KeyboardKey.leftControl);
        assert(!stroke.isDown(io));

    }

    /// Check if the stroke has been triggered during this frame.
    ///
    /// If the last item of the action is a mouse button, the action will be triggered on release. If it's a keyboard
    /// key or gamepad button, it'll be triggered on press. All previous items, if present, have to be held down at the
    /// time.
    bool isActive(const FluidBackend backend) const @trusted {

        // For all but the last item, check if it's held down
        return input[0 .. $-1].all!(a => isItemDown(backend, a))

            // For the last item, check if it's pressed or released, depending on the type
            && isItemActive(backend, input[$-1]);

    }

    unittest {

        auto singleKey = InputStroke(KeyboardKey.w);
        auto stroke = InputStroke(KeyboardKey.leftControl, KeyboardKey.leftShift, KeyboardKey.w);
        auto io = new HeadlessBackend;

        // No key pressed
        assert(!singleKey.isActive(io));
        assert(!stroke.isActive(io));

        io.press(KeyboardKey.w);

        // Just pressed the "W" key
        assert(singleKey.isActive(io));
        assert(!stroke.isActive(io));

        io.nextFrame;

        // The stroke stops being active on the next frame
        assert(!singleKey.isActive(io));
        assert(!stroke.isActive(io));

        io.press(KeyboardKey.leftControl);
        io.press(KeyboardKey.leftShift);

        assert(!singleKey.isActive(io));
        assert(!stroke.isActive(io));

        // The last key needs to be pressed during the current frame
        io.press(KeyboardKey.w);

        assert(singleKey.isActive(io));
        assert(stroke.isActive(io));

        io.release(KeyboardKey.w);

        assert(!singleKey.isActive(io));
        assert(!stroke.isActive(io));

    }

    /// Mouse actions are activated on release
    unittest {

        auto stroke = InputStroke(KeyboardKey.leftControl, MouseButton.left);
        auto io = new HeadlessBackend;

        assert(!stroke.isActive(io));

        io.press(KeyboardKey.leftControl);
        io.press(MouseButton.left);

        assert(!stroke.isActive(io));

        io.release(MouseButton.left);

        assert(stroke.isActive(io));

        // The action won't trigger if previous keys aren't held down
        io.release(KeyboardKey.leftControl);

        assert(!stroke.isActive(io));

    }

    /// Check if the given is held down.
    static bool isItemDown(const FluidBackend backend, Item item) {

        return item.match!(

            // Keyboard
            (KeyboardKey key) => backend.isDown(key),

            // A released mouse button also counts as down for our purposes, as it might trigger the action
            (MouseButton button) => backend.isDown(button) || backend.isReleased(button),

            // Gamepad
            (GamepadButton button) => backend.isDown(button) != 0
        );

    }

    /// Check if the given item is triggered.
    ///
    /// If the item is a mouse button, it will be triggered on release. If it's a keyboard key or gamepad button, it'll
    /// be triggered on press.
    static bool isItemActive(const FluidBackend backend, Item item) {

        return item.match!(
            (KeyboardKey key) => backend.isPressed(key) || backend.isRepeated(key),
            (MouseButton button) => backend.isReleased(button),
            (GamepadButton button) => backend.isPressed(button) || backend.isRepeated(button),
        );

    }

    string toString()() const {

        return format!"InputStroke(%(%s + %))"(input);

    }

}

/// Binding of an input stroke to an input action.
struct InputBinding {

    import fluid.tree.input_action;

    InputActionID action;
    InputStroke.Item trigger;

}

/// A layer groups input bindings by common key modifiers.
struct InputLayer {

    InputStroke modifiers;
    InputBinding[] bindings;

    /// When sorting ascending, the lowest value is given to the InputLayer with greatest number of bindings
    int opCmp(const InputLayer other) const {

        // You're not going to put 2,147,483,646 modifiers in a single input stroke, are you?
        return cast(int) (other.modifiers.length - modifiers.length);

    }

}
