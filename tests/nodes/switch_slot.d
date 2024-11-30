module nodes.switch_slot;

import fluid;

@safe:

@("[TODO] Legacy: SwitchSlot works")
unittest {

    Frame bigFrame, smallFrame;
    int bigDrawn, smallDrawn;

    auto io = new HeadlessBackend;
    auto slot = switchSlot(
        bigFrame = new class Frame {
            override void resizeImpl(Vector2) {
                minSize = Vector2(300, 300);
            }
            override void drawImpl(Rectangle outer, Rectangle) {
                io.drawRectangle(outer, color!"f00");
                bigDrawn++;
            }
        },
        smallFrame = new class Frame {
            override void resizeImpl(Vector2) {
                minSize = Vector2(100, 100);
            }
            override void drawImpl(Rectangle outer, Rectangle) {
                io.drawRectangle(outer, color!"0f0");
                smallDrawn++;
            }
        },
    );

    slot.io = io;

    // By default, there should be enough space to draw the big frame
    slot.draw();

    assert(slot.node is bigFrame);
    assert(bigDrawn == 1);
    assert(smallDrawn == 0);

    // Reduce the viewport, this time the small frame should be drawn
    io.nextFrame;
    io.windowSize = Vector2(200, 200);
    slot.draw();

    assert(slot.node is smallFrame);
    assert(bigDrawn == 1);
    assert(smallDrawn == 1);

    // Do it again, but make it so neither fit
    io.nextFrame;
    io.windowSize = Vector2(50, 50);
    slot.draw();

    // The small one should be drawn regardless
    assert(slot.node is smallFrame);
    assert(bigDrawn == 1);
    assert(smallDrawn == 2);

    // Unless a null node is added
    io.nextFrame;
    slot.availableNodes ~= null;
    slot.updateSize();
    slot.draw();

    assert(slot.node is null);
    assert(bigDrawn == 1);
    assert(smallDrawn == 2);

    // Resize to fit the big node
    io.nextFrame;
    io.windowSize = Vector2(400, 400);
    slot.draw();

    assert(slot.node is bigFrame);
    assert(bigDrawn == 2);
    assert(smallDrawn == 2);

}

@("[TODO] Legacy: Nodes can be moved between SwitchSlots")
unittest {

    import fluid.frame;
    import fluid.structs;

    int principalDrawn, deputyDrawn;

    auto io = new HeadlessBackend;
    auto principal = switchSlot(
        layout!(1, "fill"),
        new class Frame {
            override void resizeImpl(Vector2) {
                minSize = Vector2(200, 200);
            }
            override void drawImpl(Rectangle outer, Rectangle) {
                io.drawRectangle(outer, color!"f00");
                principalDrawn++;
            }
        },
        null
    );
    auto deputy = principal.retry(
        layout!(1, "fill"),
        new class Frame {
            override void resizeImpl(Vector2 space) {
                minSize = Vector2(50, 200);
            }
            override void drawImpl(Rectangle outer, Rectangle) {
                io.drawRectangle(outer, color!"f00");
                deputyDrawn++;
            }
        }
    );
    auto root = vframe(
        layout!(1, "fill"),
        hframe(
            layout!(1, "fill"),
            deputy,
        ),
        hframe(
            layout!(1, "fill"),
            principal,
        ),
    );

    root.io = io;

    // At the default size, the principal should be preferred
    root.draw();

    assert(principalDrawn == 1);
    assert(deputyDrawn == 0);

    // Resize the window so that the principal can't fit
    io.nextFrame;
    io.windowSize = Vector2(300, 300);

    root.draw();

    assert(principalDrawn == 1);
    assert(deputyDrawn == 1);

}

@("Deputy SwitchSlot can be placed before its principal")
unittest {

    import std.algorithm;

    import fluid.space;
    import fluid.structs;

    SwitchSlot slot;

    auto checker = new class Node {

        Vector2 size;
        Vector2[] spacesGiven;

        override void resizeImpl(Vector2 space) {

            spacesGiven ~= space;
            size = minSize = Vector2(500, 200);

        }

        override void drawImpl(Rectangle, Rectangle) {

        }

    };

    auto parentSlot = switchSlot(checker, null);
    auto childSlot = parentSlot.retry(checker);

    auto root = vspace(
        layout!"fill",
        nullTheme,

        // Two slots: child slot that gets resized earlier
        hspace(
            layout!"fill",
            childSlot,
        ),

        // Parent slot that doesn't give enough space for the child to fit
        hspace(
            layout!"fill",
            vspace(
                layout!(1, "fill"),
                parentSlot,
            ),
            vspace(
                layout!(3, "fill"),
            ),
        ),
    );

    root.draw();

    // The principal slot gives the least space, namely the width of the window divided by 4
    assert(checker.spacesGiven.map!"a.x".minElement == HeadlessBackend.defaultWindowSize.x / 4);

    // The window size that is accepted is equal to its size, as it was assigned by the fallback slot
    assert(checker.spacesGiven[$-1] == checker.size);

    // A total of three resizes were performed: one by the fallback, one by the parent and one, final, by the parent
    // using previous parameters
    assert(checker.spacesGiven.length == 3);

    // The first one (which should be the child's) has the largest width given, equal to the window width
    assert(checker.spacesGiven[0].x == HeadlessBackend.defaultWindowSize.x);

}
