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

    overlay.spawnPopup(popup, Rectangle(40, 40, 5, 5));
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
    overlay.spawnPopup(popup, Rectangle(50, 50, 0, 0));

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
