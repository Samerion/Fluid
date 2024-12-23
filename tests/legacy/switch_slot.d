@Migrated
module legacy.switch_slot;

import fluid;
import legacy;

@safe:

@("SwitchSlot works")
@Migrated
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

@("Nodes can be moved between SwitchSlots")
@Migrated
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
