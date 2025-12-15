///
module fluid.input_node;

import fluid.node;
import fluid.style;
import fluid.input;

import fluid.io.focus;
import fluid.io.hover;
import fluid.io.action;

import fluid.future.context;


@safe:

/// `InputNode` is a foundation for most nodes that accept user input. It implements the `FluidFocusable` interface,
/// and provides common functions for input handling.
abstract class InputNode(Parent : Node) : Parent, Focusable, Hoverable {

    mixin enableInputActions;

    FocusIO focusIO;
    HoverIO hoverIO;

    /// Callback to run when the input value is altered.
    void delegate() changed;

    /// Callback to run when the input is submitted.
    void delegate() submitted;

    this(T...)(T sup) {

        super(sup);

    }

    alias opEquals = typeof(super).opEquals;

    override bool opEquals(const Object other) const {
        return super.opEquals(other);
    }

    override bool blocksInput() const {
        return isDisabled || isDisabledInherited;
    }

    override bool hoverImpl(HoverPointer) {
        return false;
    }

    /// Handle keyboard and gamepad input if no input action did.
    ///
    /// Usually, you'd prefer to define a method marked with an `InputAction` enum. This function is preferred for more
    /// advanced usage.
    ///
    /// This will be called each frame as long as this node has focus, unless an `InputAction` was triggered first.
    ///
    /// Returns: True if the input was handled, false if not.
    override bool focusImpl() {
        return false;
    }

    override void resizeImpl(Vector2 space) {
        import std.traits : isAbstractFunction;

        use(focusIO);
        use(hoverIO);

        static if (!isAbstractFunction!(typeof(super).resizeImpl)) {
            super.resizeImpl(space);
        }
    }

    /// Change the focus to this node.
    void focus() {

        import fluid.actions;

        // Ignore if disabled
        if (isDisabled) return;

        // Switch focus using the active I/O technique
        focusIO.currentFocus = this;

        // Ensure this node is in view
        this.scrollIntoView();

    }

    override bool isHovered() const {

        if (hoverIO) {
            return hoverIO.isHovered(this);
        }
        else {
            return super.isHovered();
        }

    }

    override protected void focusPreviousOrNext(FluidInputAction actionType) {

        super.focusPreviousOrNext(actionType);

    }

    @(FluidInputAction.focusPrevious, FluidInputAction.focusNext)
    protected bool focusPreviousOrNextBool(FluidInputAction actionType) {

        if (focusIO) return false;
        focusPreviousOrNext(actionType);
        return true;
    }

    override protected void focusInDirection(FluidInputAction actionType) {

        super.focusInDirection(actionType);

    }

    @(FluidInputAction.focusLeft, FluidInputAction.focusRight)
    @(FluidInputAction.focusUp, FluidInputAction.focusDown)
    protected bool focusInDirectionBool(FluidInputAction action) {

        if (focusIO) return false;
        focusInDirection(action);
        return true;

    }

    /// Check if the node has focus.
    bool isFocused() const {
        if (focusIO) {
            return focusIO.isFocused(this);
        }
        else {
            return false;
        }
    }

    /// Set or remove focus from this node.
    bool isFocused(bool enable) {
        if (enable) focus();
        else if (isFocused) {
            focusIO.currentFocus = null;
        }

        return enable;
    }

}

version (TODO)
unittest {

    import fluid.label;

    // This test checks triggering and running actions bound via UDAs, including reacting to keyboard and mouse input.

    int pressCount;
    int cancelCount;

    auto io = new HeadlessBackend;
    auto root = new class InputNode!Label {

        @safe:

        mixin enableInputActions;

        this() {
            super("");
        }

        override void resizeImpl(Vector2 space) {

            minSize = Vector2(10, 10);

        }

        @(FluidInputAction.press)
        void press() {

            pressCount++;

        }

        @(FluidInputAction.cancel)
        void cancel() {

            cancelCount++;

        }

    };

    root.io = io;
    root.theme = nullTheme;
    root.focus();

    // Press the node via focus
    io.press(KeyboardKey.enter);

    root.draw();

    assert(root.tree.isFocusActive!(FluidInputAction.press));
    assert(pressCount == 1);

    io.nextFrame;

    // Holding shouldn't trigger the callback multiple times
    root.draw();

    assert(pressCount == 1);

    // Hover the node and press it with the mouse
    io.nextFrame;
    io.release(KeyboardKey.enter);
    io.mousePosition = Vector2(5, 5);
    io.press(MouseButton.left);

    root.draw();
    root.tree.focus = null;

    // This shouldn't be enough to activate the action
    assert(pressCount == 1);

    // If we now drag away from the button and release...
    io.nextFrame;
    io.mousePosition = Vector2(15, 15);
    io.release(MouseButton.left);

    root.draw();

    // ...the action shouldn't trigger
    assert(pressCount == 1);

    // But if we release the mouse on the button
    io.nextFrame;
    io.mousePosition = Vector2(5, 5);
    io.release(MouseButton.left);

    root.draw();

    assert(pressCount == 2);
    assert(cancelCount == 0);

    // Focus the node again
    root.focus();

    // Press escape to cancel
    io.nextFrame;
    io.press(KeyboardKey.escape);

    root.draw();

    assert(pressCount == 2);
    assert(cancelCount == 1);

}

version (TODO)
unittest {

    import fluid.space;
    import fluid.button;

    // This test checks if "hover slipping" happens; namely, if the user clicks and holds on an object, then hovers on
    // something else and releases, the click should be cancelled, and no other object should react to the same click.

    class SquareButton : Button {

        mixin enableInputActions;

        this(T...)(T t) {
            super(t);
        }

        override void resizeImpl(Vector2) {
            minSize = Vector2(10, 10);
        }

    }

    int[2] pressCount;
    SquareButton[2] buttons;

    auto io = new HeadlessBackend;
    auto root = hspace(
        .nullTheme,
        buttons[0] = new SquareButton("", delegate { pressCount[0]++; }),
        buttons[1] = new SquareButton("", delegate { pressCount[1]++; }),
    );

    root.io = io;

    // Press the left button
    io.mousePosition = Vector2(5, 5);
    io.press(MouseButton.left);

    root.draw();

    // Release it
    io.release(MouseButton.left);

    root.draw();

    assert(root.tree.hover is buttons[0]);
    assert(pressCount == [1, 0], "Left button should trigger");

    // Press the right button
    io.nextFrame;
    io.mousePosition = Vector2(15, 5);
    io.press(MouseButton.left);

    root.draw();

    // Release it
    io.release(MouseButton.left);

    root.draw();

    assert(pressCount == [1, 1], "Right button should trigger");

    // Press the left button, but don't release
    io.nextFrame;
    io.mousePosition = Vector2(5, 5);
    io.press(MouseButton.left);

    root.draw();

    assert( buttons[0].isPressed);
    assert(!buttons[1].isPressed);

    // Move the cursor over the right button
    io.nextFrame;
    io.mousePosition = Vector2(15, 5);

    root.draw();

    // Left button should have tree-scope hover, but isHovered status is undefined. At the time of writing, only the
    // right button will be isHovered and neither will be isPressed.
    //
    // TODO It might be a good idea to make neither isHovered. Consider new condition:
    //
    //      (_isHovered && tree.hover is this && !_isDisabled && !tree.isBranchDisabled)
    //
    // This should also fix having two nodes visually hovered in case they overlap.
    //
    // Other frameworks might retain isPressed status on the left button, but it might good idea to keep current
    // behavior as a visual clue it wouldn't trigger.
    assert(root.tree.hover is buttons[0]);

    // Release the button on the next frame
    io.nextFrame;
    io.release(MouseButton.left);

    root.draw();

    assert(pressCount == [1, 1], "Neither button should trigger on lost hover");

    // Things should go to normal next frame
    io.nextFrame;
    io.press(MouseButton.left);

    root.draw();

    // So we can expect the right button to trigger now
    io.nextFrame;
    io.release(MouseButton.left);

    root.draw();

    assert(root.tree.hover is buttons[1]);
    assert(pressCount == [1, 2]);

}
