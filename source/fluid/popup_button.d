/// [PopupButton] is a shorthand for a [Button] that opens a [PopupFrame].
///
/// Such buttons can be built using [popupButton].
module fluid.popup_button;

@safe:

import fluid.node;
import fluid.utils;
import fluid.label;
import fluid.style;
import fluid.types;
import fluid.button;
import fluid.popup_frame;

import fluid.io.overlay;

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

/// [nodeBuilder] for [PopupButton]. The button can be given a label, followed by nodes to place
/// inside the popup.
alias popupButton = nodeBuilder!PopupButton;

///
@("popupButton builder example")
unittest {
    popupButton("Open shopping list",
        label("Apples"),
        label("Flour"),
        label("Eggs"),
    );
}


/// `PopupButton` is a [Button] programmed to open a [PopupFrame] when clicked.
///
/// The popup frame will be constructed the moment the button is built, and will be reused
/// whenever it is clicked again.
///
/// `PopupButton` can be nested inside `PopupFrame`, making it convenient for creating submenus.
class PopupButton : ButtonImpl!Label {
    // ↑ For no known reason, this will not compile (producing the most misleading error of the
    // century) if extending directly from Button.

    mixin enableInputActions;

    OverlayIO overlayIO;

    public {

        /// [PopupFrame] that will be opened by this popup.
        ///
        /// The popup will be constructed by the [PopupButton] from the nodes it is initially
        /// given.
        PopupFrame popup;

        /// Popup this button is placed in, if any. Set automatically if the popup is spawned
        /// with `spawnPopup`.
        ///
        /// This field will be removed in Fluid 0.8.0.
        PopupFrame parentPopup;

    }

    private {

        Rectangle _inner;

        // workaround for https://git.samerion.com/Samerion/Fluid/issues/401
        // could be fixed with https://git.samerion.com/Samerion/Fluid/issues/399
        bool _justOpened;

    }

    /// Create a new button, and build the popup that will appear whenever the button is clicked.
    /// Params:
    ///     text          = Text for the button. See [Label.text][fluid.label.Label.text].
    ///     popupChildren = Children to place in the popup. They will be grouped together inside
    ///         a [PopupFrame] and displayed when the button is clicked.
    this(string text, Node[] popupChildren...) {

        // Craft the popup
        popup = popupFrame(popupChildren);

        super(text, delegate {
            const anchor = focusBoxImpl(_inner);

            // Parent popup active
            if (parentPopup && parentPopup.isFocused)
                overlayIO.addChildPopup(parentPopup, popup, anchor);

            // No parent
            else {
                overlayIO.addPopup(popup, anchor);
            }

            _justOpened = true;
        });

    }

    override void resizeImpl(Vector2 space) {
        use(overlayIO);
        super.resizeImpl(space);
    }

    override void drawImpl(Rectangle outer, Rectangle inner) {
        _inner = inner;
        super.drawImpl(outer, inner);
        if (hoverIO && !hoverIO.isHovered(this)) {
            _justOpened = false;
        }
    }

    override void focus() {
        if (hoverIO && _justOpened) return;
        super.focus();
    }

    override string toString() const {
        import std.format;
        return format!"popupButton(%s)"(text);
    }

}
