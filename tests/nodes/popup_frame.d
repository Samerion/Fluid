module nodes.popup_frame;

import fluid;

@safe:

@("PopupFrames can be spawned")
unittest {

    auto overlay = overlayChain(
        .layout!(1, "fill")
    );
    auto root = sizeLock!testSpace(
        .nullTheme,
        .sizeLimit(600, 600),
        overlay
    );
    auto popup = popupFrame(
        label("This is my popup"),
    );

    overlay.addPopup(popup, Rectangle(40, 40, 5, 5));
    root.drawAndAssert(
        overlay.drawsChild(popup),
        popup.isDrawn().at(45, 45),
        overlay.doesNotDrawChildren(),
    );

}

@("Popups disappear when clicked outside")
unittest {

    auto overlay = overlayChain();
    auto hover = hoverChain();
    auto focus = focusChain();
    auto root = testSpace(
        .nullTheme,
        chain(
            focus,
            hover,
            overlay
        ),
    );
    auto popup = sizeLock!popupFrame(
        .layout!"start",
        .sizeLimit(100, 100),
    );
    overlay.addPopup(popup, Rectangle(50, 50, 0, 0));

    root.drawAndAssert(
        overlay.drawsChild(popup),
        popup.isDrawn().at(50, 50, 100, 100),
        overlay.doesNotDrawChildren(),
    );
    root.drawAndAssert(
        overlay.drawsChild(popup),
        popup.isDrawn().at(50, 50, 100, 100),
        overlay.doesNotDrawChildren(),
    );

    hover.point(25, 25)
        .then((a) {
            a.click;
            return a.stayIdle;
        })
        .runWhileDrawing(root, 2);

    root.draw();
    root.drawAndAssert(
        overlay.doesNotDrawChildren(),
    );
    root.drawAndAssertFailure(
        popup.isDrawn(),
    );

}

@("PopupFrame stays focused and visible as long as a child node is focused")
unittest {

    auto overlay = overlayChain();
    auto hover = hoverChain();
    auto focus = focusChain();
    auto root = testSpace(
        .nullTheme,
        chain(
            focus,
            hover,
            overlay
        ),
    );

    Button innerButton, outerButton;
    auto popup = sizeLock!popupFrame(
        hspace(
            innerButton = button("Foo", delegate { }),
        ),
        outerButton = button("Bar", delegate { }),
    );
    overlay.addPopup(popup, Rectangle(0, 0, 0, 0));

    root.drawAndAssert(
        popup.isDrawn(),
        innerButton.isDrawn(),
        outerButton.isDrawn(),
    );
    // The first item in the popup should be chosen for focus
    assert(focus.isFocused(popup));
    assert(popup.FocusIO.isFocused(innerButton));
    assert( popup.isFocused);
    assert( innerButton.isFocused);
    assert(!outerButton.isFocused);

    outerButton.focus();
    root.drawAndAssert(
        popup.isDrawn(),
    );
    assert(focus.isFocused(popup));
    assert(popup.FocusIO.isFocused(outerButton));
    assert( popup.isFocused);
    assert(!innerButton.isFocused);
    assert( outerButton.isFocused);

    // Focus cleared, close the popup
    focus.clearFocus();
    root.draw();
    assert(!focus.isFocused(popup));
    assert(!popup.FocusIO.isFocused(outerButton));
    assert(!popup.isFocused);
    assert(!innerButton.isFocused);
    assert(!outerButton.isFocused);
    root.drawAndAssertFailure(
        popup.isDrawn(),
    );

}

@("PopupFrames can be exited with a cancel action")
unittest {

    auto overlay = overlayChain();
    auto hover = hoverChain();
    auto focus = focusChain();
    auto root = testSpace(
        .nullTheme,
        chain(
            focus,
            hover,
            overlay
        ),
    );

    Button btn;
    auto popup = sizeLock!popupFrame(
        btn = button("Bar", delegate { }),
    );
    overlay.addPopup(popup, Rectangle(0, 0, 0, 0));

    root.drawAndAssert(popup.isDrawn);
    focus.runInputAction!(FluidInputAction.cancel);
    root.draw();
    root.drawAndAssertFailure(popup.isDrawn);

}
