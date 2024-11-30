///
module fluid.popup_button;

import fluid.node;
import fluid.utils;
import fluid.label;
import fluid.style;
import fluid.button;
import fluid.popup_frame;

@safe:

/// A button made to open popups.
alias popupButton = simpleConstructor!PopupButton;

// For no known reason, this will not compile (producing the most misleading error of the century) if extending directly
// from Button.

/// ditto
class PopupButton : ButtonImpl!Label {

    mixin enableInputActions;

    public {

        /// Popup enabled by this button.
        PopupFrame popup;

        /// Popup this button belongs to, if any. Set automatically if the popup is spawned with `spawnPopup`.
        PopupFrame parentPopup;

    }

    /// Create a new button.
    /// Params:
    ///     text          = Text for the button.
    ///     popupChildren = Children to appear within the button.
    this(string text, Node[] popupChildren...) {

        // Craft the popup
        popup = popupFrame(popupChildren);

        super(text, delegate {

            // Parent popup active
            if (parentPopup && parentPopup.isFocused)
                parentPopup.spawnChildPopup(popup);

            // No parent
            else {
                popup.theme = theme;
                tree.spawnPopup(popup);
            }

        });

    }

    override string toString() const {

        import std.format;
        return format!"popupButton(%s)"(text);

    }

}

///
unittest {

    auto myButton = popupButton("Options",
        button("Edit", delegate { }),
        button("Copy", delegate { }),
        popupButton("Share",
            button("SMS", delegate { }),
            button("Via e-mail", delegate { }),
            button("Send to device", delegate { }),
        ),
    );

}
