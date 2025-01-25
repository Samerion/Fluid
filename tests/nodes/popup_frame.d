module nodes.popup_frame;

import fluid;
import fluid.future.pipe;

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
    auto focus = focusChain();
    auto root = testSpace(
        .nullTheme,
        chain(
            focus,
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
    auto focus = focusChain();
    auto root = testSpace(
        .nullTheme,
        chain(
            focus,
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
    root.drawAndAssertFailure(popup.isDrawn);

}

@("PopupFrames can be exited with an escape key")
unittest {

    auto overlay = overlayChain();
    auto focus = focusChain();
    auto root = testSpace(
        .nullTheme,
        chain(
            inputMapChain(),
            focus,
            overlay
        ),
    );

    Button btn;
    auto popup = sizeLock!popupFrame(
        btn = button("Bar", delegate { }),
    );
    overlay.addPopup(popup, Rectangle(0, 0, 0, 0));

    root.drawAndAssert(popup.isDrawn);
    assert(focus.isFocused(popup));
    focus.emitEvent(KeyboardIO.press.escape);
    root.draw();
    assert(!focus.isFocused(popup));
    root.drawAndAssertFailure(popup.isDrawn);

}

@("PopupFrame children can accept focus and input")
unittest {

    auto overlay = overlayChain();
    auto focus = focusChain();
    auto root = testSpace(
        .nullTheme,
        chain(
            inputMapChain(),
            focus,
            overlay
        ),
    );

    Button button1, button2;
    int pressed1, pressed2;
    auto popup = sizeLock!popupFrame(
        button1 = button("Foo", delegate {
            pressed1++;
        }),
        button2 = button("Bar", delegate {
            pressed2++;
        }),
    );
    overlay.addPopup(popup, Rectangle(0, 0, 0, 0));

    root.draw();
    assert( button1.isFocused);
    assert(!button2.isFocused);
    assert( popup.isFocused);
    button2.focus();
    assert(!button1.isFocused);
    assert( button2.isFocused);
    assert( popup.isFocused);

    assert(pressed1 == 0);
    assert(pressed2 == 0);
    focus.runInputAction!(FluidInputAction.press);
    assert(pressed1 == 0);
    assert(pressed2 == 1);

}

@("PopupFrame triggers focusImpl")
unittest {

    import nodes.focus_chain : focusTracker;

    auto overlay = overlayChain();
    auto focus = focusChain();
    auto root = testSpace(
        .nullTheme,
        chain(
            inputMapChain(),
            focus,
            overlay
        ),
    );

    auto tracker = focusTracker();
    auto popup = sizeLock!popupFrame(
        tracker,
    );
    overlay.addPopup(popup, Rectangle(0, 0, 0, 0));

    // TODO This focus call shouldn't be necessary;
    //      focusRecurse currently requires FluidFocusable
    root.draw();
    tracker.focus();

    root.draw();
    assert(popup.isFocused);
    assert(tracker.isFocused);
    assert(tracker.focusImplCalls == 1);
    root.draw();
    assert(tracker.focusImplCalls == 2);
    focus.runInputAction!(FluidInputAction.press);
    root.draw();
    assert(tracker.pressCalls == 1);
    assert(tracker.focusImplCalls == 2);

}

@("PopupFrame implements tabbing and tab wrapping")
unittest {

    Button button1, button2, button3;

    auto overlay = overlayChain();
    auto focus = focusChain(overlay);
    auto root = testSpace(.nullTheme, focus);
    auto popup = sizeLock!popupFrame(
        button1 = button("One", delegate { }),
        button2 = button("Two", delegate { }),
        button3 = button("Three", delegate { }),
    );
    overlay.addPopup(popup, Rectangle(0, 0, 0, 0));

    root.draw();

    // Forwards
    focus.runInputAction!(FluidInputAction.focusNext);
    root.draw();
    assert(popup.FocusIO.isFocused(button2));

    focus.runInputAction!(FluidInputAction.focusNext);
    root.draw();
    assert(popup.FocusIO.isFocused(button3));

    focus.runInputAction!(FluidInputAction.focusNext);
    root.draw();
    assert(popup.FocusIO.isFocused(button1));

    // Backwards
    focus.runInputAction!(FluidInputAction.focusPrevious);
    root.draw();
    assert(popup.FocusIO.isFocused(button3));

    focus.runInputAction!(FluidInputAction.focusPrevious);
    root.draw();
    assert(popup.FocusIO.isFocused(button2));

    focus.runInputAction!(FluidInputAction.focusPrevious);
    root.draw();
    assert(popup.FocusIO.isFocused(button1));


}

@("PopupFrame implements positional focus")
unittest {

    Button button1, button2, button3;

    auto overlay = overlayChain();
    auto focus = focusChain(overlay);
    auto root = testSpace(.nullTheme, focus);
    auto popup = sizeLock!popupFrame(
        hspace(
            button1 = button("One", delegate { }),
            button2 = button("Two", delegate { }),
        ),
        button3 = button("Three", delegate { }),
    );
    overlay.addPopup(popup, Rectangle(0, 0, 0, 0));

    root.draw();

    // Horizontal
    focus.runInputAction!(FluidInputAction.focusRight);
    root.draw();
    assert(popup.FocusIO.isFocused(button2));
    root.draw();

    focus.runInputAction!(FluidInputAction.focusLeft);
    root.draw();
    assert(popup.FocusIO.isFocused(button1));
    root.draw();

    focus.runInputAction!(FluidInputAction.focusLeft);
    root.draw();
    assert(popup.FocusIO.isFocused(button1));
    root.draw();

    // Vertical
    focus.runInputAction!(FluidInputAction.focusDown);
    root.draw();
    assert(popup.FocusIO.isFocused(button3));
    root.draw();

    focus.runInputAction!(FluidInputAction.focusDown);
    root.draw();
    assert(popup.FocusIO.isFocused(button3));
    root.draw();

    focus.runInputAction!(FluidInputAction.focusUp);
    root.draw();
    assert(popup.FocusIO.isFocused(button1));
    root.draw();


}
