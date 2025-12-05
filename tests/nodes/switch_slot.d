module nodes.switch_slot;

import fluid;

@safe:

unittest {

    Node bigNode, smallNode;

    auto slot = switchSlot(
        bigNode = new class Frame {

            override void resizeImpl(Vector2 space) {
                super.resizeImpl(space);
                minSize = Vector2(300, 300);
            }

        },
        smallNode = new class Frame {

            override void resizeImpl(Vector2 space) {
                super.resizeImpl(space);
                minSize = Vector2(100, 100);
            }

        },
    );
    auto root = sizeLock!testSpace(
        .sizeLimit(800, 600),
        .nullTheme,
        slot
    );

    // At start, there should be enough space to draw the big frame
    root.drawAndAssert(
        slot.drawsChild(bigNode),
        slot.doesNotDrawChildren(),
    );
    assert(slot.node is bigNode);

    // Reduce the viewport, this time the small frame should be drawn
    root.limit = sizeLimit(200, 200);
    root.updateSize();
    root.drawAndAssert(
        slot.drawsChild(smallNode),
        slot.doesNotDrawChildren(),
    );
    assert(slot.node is smallNode);

    // Do it again, but make it so neither fit; the small one should prevail anyway
    root.limit = sizeLimit(50, 50);
    root.updateSize();
    root.drawAndAssert(
        slot.drawsChild(smallNode),
        slot.doesNotDrawChildren(),
    );
    assert(slot.node is smallNode);

    // Unless a null node is added
    slot.availableNodes ~= null;
    root.updateSize();
    root.drawAndAssertFailure(
        slot.isDrawn(),
    );
    assert(slot.node is null);

    // Resize to fit the big node
    root.limit = sizeLimit(400, 400);
    root.updateSize();
    root.drawAndAssert(
        slot.drawsChild(bigNode),
        slot.doesNotDrawChildren(),
    );
    assert(slot.node is bigNode);

}

@("Nodes can be moved between SwitchSlots")
unittest {

    int principalDrawn, deputyDrawn;

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
    auto root = sizeLock!testSpace(
        .layout!(1, "fill"),
        .sizeLimit(600, 600),
        hframe(
            .layout!(1, "fill"),
            deputy,
        ),
        hframe(
            .layout!(1, "fill"),
            principal,
        ),
    );

    // At the initial size, the principal should be preferred
    root.draw();

    assert(principalDrawn == 1);
    assert(deputyDrawn == 0);

    // Resize the window so that the principal can't fit
    root.limit = sizeLimit(300, 300);
    root.updateSize();
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
