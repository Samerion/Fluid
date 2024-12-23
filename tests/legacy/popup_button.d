@Migrated
module legacy.popup_button;

import fluid;
import legacy;

@safe:

@("PopupButton supports keyboard navigation")
@Migrated
unittest {

    import fluid.backend;

    string lastAction;

    void action(string text)() {
        lastAction = text;
    }

    Button[6] buttons;

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

    auto sharePopupButton = cast(PopupButton) buttons[2];
    auto sharePopup = sharePopupButton.popup;

    root.io = io;
    root.draw();

    import std.stdio;

    // Focus the button
    {
        io.nextFrame;
        io.press(KeyboardKey.down);

        root.draw();

        assert(root.isFocused);
    }

    // Press it
    {
        io.nextFrame;
        io.release(KeyboardKey.down);
        io.press(KeyboardKey.enter);

        root.draw();
    }

    // Popup opens
    {
        io.nextFrame;
        io.release(KeyboardKey.enter);

        root.draw();

        assert(buttons[0].isFocused, "The first button inside should be focused");
    }

    // Go to the previous button, expecting wrap
    {
        io.nextFrame;
        io.press(KeyboardKey.leftShift);
        io.press(KeyboardKey.tab);

        root.draw();

        assert(buttons[2].isFocused, "The last button inside the first menu should be focused");
    }

    // Press it
    {
        io.nextFrame;
        io.release(KeyboardKey.leftShift);
        io.release(KeyboardKey.tab);
        io.press(KeyboardKey.enter);

        root.draw();
    }

    // Wait for the popup to appear
    {
        io.nextFrame;
        io.release(KeyboardKey.enter);

        root.draw();
        assert(buttons[3].isFocused, "The first button of the second menu should be focused");
    }

    // Press the up arrow, it should do nothing
    {
        io.nextFrame;
        io.press(KeyboardKey.up);

        root.draw();
        assert(buttons[3].isFocused);
    }

    // Press the down arrow
    {
        io.nextFrame;
        io.release(KeyboardKey.up);
        io.press(KeyboardKey.down);

        root.draw();
        assert(buttons[4].isFocused);
    }

    // Press the button
    {
        io.nextFrame;
        io.release(KeyboardKey.down);
        io.press(KeyboardKey.enter);

        root.draw();
        assert(buttons[4].isFocused);
        assert(lastAction == "email");
        assert(!sharePopup.isHidden);

    }

    // Close the popup by pressing escape
    {
        io.nextFrame;
        io.release(KeyboardKey.enter);
        io.press(KeyboardKey.escape);

        root.draw();

        // Need another frame for the tree action
        io.nextFrame;
        root.draw();

        assert(sharePopup.isHidden);
    }

}
