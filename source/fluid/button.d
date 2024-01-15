///
module fluid.button;

import fluid.node;
import fluid.frame;
import fluid.input;
import fluid.label;
import fluid.utils;
import fluid.style;
import fluid.backend;

alias button = simpleConstructor!(FluidButton!FluidLabel);
alias frameButton = simpleConstructor!(FluidButton!FluidFrame);

@safe:

/// A button can be pressed by the user to trigger an action.
///
/// Styles: $(UL
///   $(LI `styleKey` = Default style for the button.)
///   $(LI `hoverStyleKey` = Style to apply when the button is hovered.)
///   $(LI `pressStyleKey` = Style to apply when the button is pressed.)
///   $(LI `focusStyleKey` = Style to apply when the button is focused.)
/// )
class FluidButton(T : FluidNode = FluidLabel) : FluidInput!T {

    mixin DefineStyles!(
        "pressStyle", q{ hoverStyle },
    );
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
    protected void _pressed() @trusted {

        // Run the callback
        pressed();

    }

    /// Pick the style.
    protected override inout(Style) pickStyle() inout {

        // If pressed
        if (isPressed) return pressStyle;

        // If focused
        if (isFocused) return focusStyle;

        // If hovered
        if (isHovered) return hoverStyle;

        // No decision — normal state
        return super.pickStyle();

    }

    static if (is(typeof(text) : string))
    override string toString() const {

        import std.format;
        return format!"button(%s)"(text);

    }

}
