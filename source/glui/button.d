///
module glui.button;

import raylib;

import glui.node;
import glui.frame;
import glui.input;
import glui.label;
import glui.utils;
import glui.style;

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

    /// Mouse button to trigger the button.
    private static immutable triggerButton = MouseButton.MOUSE_LEFT_BUTTON;

    /// Callback to run when the button is pressed.
    alias pressed = submitted;

    // Button status
    struct {

        // If true, this button is currenly down.
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

        // Draw the button
        super.drawImpl(outer, inner);

        // Reset pressed status
        isPressed = false;

    }

    /// Handle mouse input. By default, this will call the `pressed` delegate if the button is pressed.
    protected override void mouseImpl() @trusted {

        // Just released
        if (IsMouseButtonReleased(triggerButton)) {

            isPressed = true;
            pressed();

        }

    }

    /// Handle keyboard input.
    protected override bool keyboardImpl() @trusted {

        // Pressed enter
        if (IsKeyReleased(KeyboardKey.KEY_ENTER)) {

            isPressed = true;
            pressed();
            return true;

        }

        return IsKeyDown(KeyboardKey.KEY_ENTER);

    }

    /// Pick the style.
    protected override const(Style) pickStyle() const {

        alias pressing = () @trusted => IsMouseButtonDown(triggerButton);

        // If pressed
        if (isHovered && pressing()) return pressStyle;

        // If focused
        if (isFocused) return focusStyle;

        // If hovered
        if (isHovered) return hoverStyle;

        // No decision — normal state
        return super.pickStyle();

    }

    static if (__traits(compiles, text))
    override string toString() const {

        import std.format;
        return format!"button(%s)"(text);

    }

}
