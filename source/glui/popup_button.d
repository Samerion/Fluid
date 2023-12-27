///
module glui.popup_button;

import glui.node;
import glui.utils;
import glui.label;
import glui.button;
import glui.popup_frame;
import glui.style_macros;

alias popupButton = simpleConstructor!(GluiPopupButton);

@safe:

/// A button specifically to handle popups.
class GluiPopupButton : GluiButton!GluiLabel {

    mixin defineStyles;
    mixin enableInputActions;

    public {

        /// Popup enabled by this button.
        GluiPopupFrame popup;

        /// Popup this button belongs to, if any. Set automatically if the popup is spawned with `spawnPopup`.
        GluiPopupFrame parentPopup;

    }

    /// Create a new button.
    /// Params:
    ///     params        = Generic node parameters for the button.
    ///     text          = Text for the button.
    ///     popupChildren = Children to appear within the button.
    this(NodeParams params, string text, GluiNode[] popupChildren...) {

        // Craft the popup
        popup = popupFrame(popupChildren);

        super(params, text, delegate {

            // Parent popup active
            if (parentPopup && parentPopup.isFocused)
                parentPopup.spawnChildPopup(popup);

            // No parent
            else
                tree.spawnPopup(popup);

        });

    }

    override string toString() const {

        import std.format;
        return format!"popupButton(%s)"(text);

    }

}
