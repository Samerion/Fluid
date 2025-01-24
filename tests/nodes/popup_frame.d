module nodes.popup_frame;

import fluid;

@safe:

@("Popups can be spawned")
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
    );

}
