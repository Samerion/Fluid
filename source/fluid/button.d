///
module fluid.button;

import fluid.node;
import fluid.frame;
import fluid.input;
import fluid.label;
import fluid.utils;
import fluid.style;
import fluid.backend;

alias button = simpleConstructor!Button;
deprecated("Use vframeButton instead")
alias frameButton = simpleConstructor!FrameButton;
alias hframeButton = simpleConstructor!(FrameButton, (a) {
    a.isHorizontal = true;
});
alias vframeButton = simpleConstructor!FrameButton;
alias Button = ButtonImpl!Label;
alias FrameButton = ButtonImpl!Frame;

@safe:

/// A button can be pressed by the user to trigger an action.
class ButtonImpl(T : Node = Label) : InputNode!T {

    mixin enableInputActions;

    /// Callback to run when the button is pressed.
    alias pressed = submitted;

    // Button status
    public {

        // If true, this button is currenly held down.
        bool isPressed;

    }

    /// Create a new button.
    /// Params:
    ///     pressed = Action to perform when the button is pressed.
    this(T...)(T sup, void delegate() @trusted pressed) {

        super(sup);
        this.pressed = pressed;

    }

    protected override void drawImpl(Rectangle outer, Rectangle inner) {

        // Check if pressed
        isPressed = checkIsPressed;
        // TODO this should be *false* if key is held down, but wasn't pressed while in focus

        // Draw the button
        super.drawImpl(outer, inner);

    }

    /// Handle mouse input. By default, this will call the `pressed` delegate if the button is pressed.
    @(FluidInputAction.press)
    void press() @trusted {

        // Run the callback
        if (pressed) pressed();

    }

    static if (is(typeof(text) : string))
    override string toString() const {

        import std.format;
        return format!"button(%s)"(text);

    }

}
