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

    override bool opEquals(const Object other) const {
        return super.opEquals(other);
    }

    override bool blocksInput() const {
        return isDisabled;
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

        require(focusIO);
        require(hoverIO);

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
