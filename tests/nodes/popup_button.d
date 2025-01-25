module nodes.popup_button;

import fluid;
import fluid.future.pipe;

@safe:

@("PopupButton supports keyboard navigation")
unittest {

    import fluid.backend;

    string lastAction;

    void action(string text)() {
        lastAction = text;
    }

    Button[6] buttons;

    auto main = popupButton("Options",
        buttons[0] = button("Edit", &action!"edit"),
        buttons[1] = button("Copy", &action!"copy"),
        buttons[2] = popupButton("Share",
            buttons[3] = button("SMS", &action!"sms"),
            buttons[4] = button("Via e-mail", &action!"email"),
            buttons[5] = button("Send to device", &action!"device"),
        ),
    );
    auto focus = focusChain(nullTheme, main);
    auto overlay = overlayChain(focus);
    auto root = overlay;

    auto sharePopupButton = cast(PopupButton) buttons[2];
    auto sharePopup = sharePopupButton.popup;

    root.draw();

    // Focus the button
    focus.focusNext()
        .thenAssertEquals(main)

        // Press it
        .then(() => focus.runInputAction!(FluidInputAction.press))
        .then(_ => root.nextFrame)

        // A popup should open
        .then(() => assert(focus.isFocused(buttons[0]), "The first button inside should be focused"))

        // Go to the previous button, expecting wrap
        .then(() => focus.runInputAction!(FluidInputAction.focusPrevious))
        .then(_ => root.nextFrame)
        .then(() => assert(focus.isFocused(buttons[2]), "The last button inside the first menu should be focused"))

        // Press the last button
        .then(() => buttons[2].press())
        .then(() => root.nextFrame)
        .then(() => assert(focus.isFocused(buttons[3]), "The first button of the second menu should be focused"))

        // The up arrow should do nothing
        .then(() => focus.runInputAction!(FluidInputAction.focusUp))
        .then(_ => root.nextFrame)
        .then(() => assert(focus.isFocused(buttons[3])))

        // Press the down arrow
        .then(() => focus.runInputAction!(FluidInputAction.focusDown))
        .then(_ => root.nextFrame)
        .then(() => assert(focus.isFocused(buttons[4])))

        // Press the button
        .then(() => buttons[4].press)
        .then(() => assert(focus.isFocused(buttons[4])))
        .then(() => assert(lastAction == "email"))
        .then(() => assert(!sharePopup.isHidden))

        // Close the popup
        .then(() => focus.runInputAction!(FluidInputAction.cancel))

        // Need two frames to process the tree action
        .then(_ => main.nextFrame)
        .then(() => main.nextFrame)

        // Need another frame for the tree action
        .then(() => assert(sharePopup.isHidden));

}

@("PopupButton uses OverlayIO to create the popup")
unittest {

    auto button = popupButton("Hello",
        label("Popup opened"),
    );
    auto overlay = overlayChain(
        .layout!(1, "fill"),
        button
    );
    auto root = sizeLock!testSpace(
        .nullTheme,
        .sizeLimit(400, 400),
        overlay
    );

    root.drawAndAssert(button.isDrawn);
    root.drawAndAssertFailure(button.popup.isDrawn);

    button.press();

    root.drawAndAssert(
        button.isDrawn,
        button.popup.isDrawn.at(button.getMinSize),
    );
    root.drawAndAssert(
        overlay.drawsChild(button.popup),
    );

}
