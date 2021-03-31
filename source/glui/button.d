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

/// A button can be pressed by the user to trigger an action.
///
/// Styles: $(UL
///   $(LI `styleKey` = Default style for the button.)
///   $(LI `hoverStyleKey` = Style to apply when the button is hovered.)
///   $(LI `pressStyleKey` = Style to apply when the button is pressed.)
///   $(LI `focusStyleKey` = Style to apply when the button is focused.)
/// )
class GluiButton(T : GluiNode) : GluiInput!T {

    mixin DefineStyles!(
        "hoverStyle", q{ style },
        "pressStyle", q{ hoverStyle },
    );

    /// Mouse button to trigger the button.
    private static immutable triggerButton = MouseButton.MOUSE_LEFT_BUTTON;
    // TODO left handed support?

    /// Callback to run when the button is pressed.
    alias pressed = submitted;

    // Button status
    struct {

        /// If true, this button is currently being hovered.
        bool isHovered;

        // If true, this button is currenly down.
        bool isPressed;

    }

    /// Create a new button.
    /// Params:
    ///     pressed = Action to perform when the button is pressed.
    this(T...)(T sup, void delegate() pressed) {

        super(sup);
        this.pressed = pressed;

    }

    protected override void drawImpl(Rectangle area) {

        // Update status
        isHovered = area.contains(GetMousePosition);
        isPressed = isHovered && IsMouseButtonDown(triggerButton);
        // TODO: Keyboard support

        handleInput();

        super.drawImpl(area);

    }

    /// Handle button input. By default, this will call the `pressed` delegate if the button is pressed.
    protected void handleInput() {

        // Handle events
        if (isHovered && IsMouseButtonReleased(triggerButton)) {

            // Call the delegate
            pressed();

        }

    }

    /// Pick the style.
    protected override const(Style) pickStyle() const {

        const(Style)* result;

        // If hovered
        if (isHovered) {

            // Set cursor
            SetMouseCursor(MouseCursor.MOUSE_CURSOR_POINTING_HAND);

            // Use the style
            result = &hoverStyle;

        }

        // If pressed — override hover
        if (isPressed) result = &pressStyle;


        // Return the result
        if (result) return *result;

        // No decision — normal state
        else return super.pickStyle();

    }

}
