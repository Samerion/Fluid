///
module fluid.popup_button;

import fluid.node;
import fluid.utils;
import fluid.label;
import fluid.button;
import fluid.popup_frame;
import fluid.style_macros;

@safe:

/// A button made to open popups.
alias popupButton = simpleConstructor!(GluiPopupButton);

/// ditto
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

unittest {

    import fluid.backend;

    string lastAction;

    void action(string text)() {
        lastAction = text;
    }

    GluiButton!()[6] buttons;

    auto io = new HeadlessBackend;
    auto root = popupButton("Options",
        buttons[0] = button("Edit", &action!"edit"),
        buttons[1] = button("Copy", &action!"copy"),
        buttons[2] = popupButton("Share",
            buttons[3] = button("SMS", &action!"sms"),
            buttons[4] = button("Via e-mail", &action!"email"),
            buttons[5] = button("Send to device", &action!"device"),
        ),
    );

    auto sharePopupButton = cast(GluiPopupButton) buttons[2];
    auto sharePopup = sharePopupButton.popup;

    root.io = io;
    root.draw();

    import std.stdio;

    // Focus the button
    {
        io.nextFrame;
        io.press(GluiKeyboardKey.down);

        root.draw();

        assert(root.isFocused);
    }

    // Press it
    {
        io.nextFrame;
        io.release(GluiKeyboardKey.down);
        io.press(GluiKeyboardKey.enter);

        root.draw();
    }

    // Popup opens
    {
        io.nextFrame;
        io.release(GluiKeyboardKey.enter);

        root.draw();

        assert(buttons[0].isFocused, "The first button inside should be focused");
    }

    // Go to the previous button, expecting wrap
    {
        io.nextFrame;
        io.press(GluiKeyboardKey.leftShift);
        io.press(GluiKeyboardKey.tab);

        root.draw();

        assert(buttons[2].isFocused, "The last button inside the first menu should be focused");
    }

    // Press it
    {
        io.nextFrame;
        io.release(GluiKeyboardKey.leftShift);
        io.release(GluiKeyboardKey.tab);
        io.press(GluiKeyboardKey.enter);

        root.draw();
    }

    // Wait for the popup to appear
    {
        io.nextFrame;
        io.release(GluiKeyboardKey.enter);

        root.draw();
        assert(buttons[3].isFocused, "The first button of the second menu should be focused");
    }

    // Press the up arrow, it should do nothing
    {
        io.nextFrame;
        io.press(GluiKeyboardKey.up);

        root.draw();
        assert(buttons[3].isFocused);
    }

    // Press the down arrow
    {
        io.nextFrame;
        io.release(GluiKeyboardKey.up);
        io.press(GluiKeyboardKey.down);

        root.draw();
        assert(buttons[4].isFocused);
    }

    // Press the button
    {
        io.nextFrame;
        io.release(GluiKeyboardKey.down);
        io.press(GluiKeyboardKey.enter);

        root.draw();
        assert(buttons[4].isFocused);
        assert(lastAction == "email");
        assert(!sharePopup.isHidden);

    }

    // Close the popup by pressing escape
    {
        io.nextFrame;
        io.release(GluiKeyboardKey.enter);
        io.press(GluiKeyboardKey.escape);

        root.draw();

        // Need another frame for the tree action
        io.nextFrame;
        root.draw();

        assert(sharePopup.isHidden);
    }

}
