///
module glui.button;

import glui.node;
import glui.frame;
import glui.input;
import glui.label;
import glui.utils;
import glui.style;
import glui.backend;

alias button = simpleConstructor!(GluiButton!GluiLabel);
alias frameButton = simpleConstructor!(GluiButton!GluiFrame);

@safe:

/// A button can be pressed by the user to trigger an action.
///
/// Styles: $(UL
///   $(LI `styleKey` = Default style for the button.)
///   $(LI `hoverStyleKey` = Style to apply when the button is hovered.)
///   $(LI `pressStyleKey` = Style to apply when the button is pressed.)
///   $(LI `focusStyleKey` = Style to apply when the button is focused.)
/// )
class GluiButton(T : GluiNode = GluiLabel) : GluiInput!T {

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

        // Draw the button
        super.drawImpl(outer, inner);

    }

    /// Handle mouse input. By default, this will call the `pressed` delegate if the button is pressed.
    @(GluiInputAction.press)
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
