module nodes.size_lock;

import fluid;

@safe:

@("sizeLock supports hspace")
unittest {

    assert(sizeLock!vspace().isHorizontal == false);
    assert(sizeLock!hspace().isHorizontal == true);

}

@("SizeLock changes the size given to a node")
unittest {

    auto lock = sizeLock!vframe(
        .layout!(1, "center", "fill"),
        .sizeLimitX(400),
        label("Hello, World!"),
    );
    auto root = sizeLock!testSpace(
        .layout!"fill",
        .sizeLimit(800, 600),
        lock,
    );

    with (Rule)
    root.theme = nullTheme.derive(
        rule!Frame(backgroundColor = color!"1c1c1c"),
        rule!Label(textColor = color!"eee"),
    );

    // The rectangle should display neatly in the middle of the display, limited to 400px
    root.drawAndAssert(
        lock.drawsRectangle(200, 0, 400, 600).ofColor("#1c1c1c"),
    );

    // Try different layouts: it can also be placed on the left
    lock.layout = layout!(1, "start", "fill");
    root.updateSize();
    root.drawAndAssert(
        lock.drawsRectangle(0, 0, 400, 600).ofColor("#1c1c1c"),
    );

    // Center, also vertically, with a square limit
    lock.layout = layout!(1, "center");
    lock.limit = sizeLimit(200, 200);
    root.updateSize();
    root.drawAndAssert(
        lock.drawsRectangle(300, 200, 200, 200).ofColor("#1c1c1c"),
    );

}

