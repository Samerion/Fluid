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
///   $(LI `focusStyleKey` = Style to apply when the button is focused. (TODO))
/// )
class GluiButton(T : GluiNode) : GluiInput!T {

    mixin DefineStyles!(
        "hoverStyle", q{ style },
        "pressStyle", q{ hoverStyle },
    );

    /// Callback to run when the button is pressed.
    alias pressed = submitted;

    /// Create a new button.
    /// Params:
    ///     pressed = Action to perform when the button is pressed.
    this(T...)(T sup, void delegate() pressed) {

        super(sup);
        this.pressed = pressed;

    }

    /// Pick the style.
    protected override const(Style) pickStyle(Rectangle area) const {

        // If focused
        if (false) { }

        // If hovered
        else if (area.contains(GetMousePosition)) {

            SetMouseCursor(MouseCursor.MOUSE_CURSOR_POINTING_HAND);

            // If pressed
            if (IsMouseButtonPressed(MouseButton.MOUSE_LEFT_BUTTON)) {

                pressed();
                return pressStyle;

            }

            // If not
            return hoverStyle;

        }

        // Inactive

        // Normal state
        else return style;

    }

}
