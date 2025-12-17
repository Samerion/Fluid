module nodes.drag_slot;

import fluid;

@safe:

alias resizable = nodeBuilder!Resizable;

class Resizable : Node {

    Vector2 size;

    this(Vector2 size) {
        this.size = size;
    }

    override void resizeImpl(Vector2) {
        minSize = size;
    }

    override void drawImpl(Rectangle, Rectangle) {

    }

    override HitFilter inBoundsImpl(Rectangle, Rectangle, Vector2) {
        return HitFilter.miss;
    }

}

Theme testTheme;

const frameColor = color("#fdc798");

static this() {
    import fluid.theme;
    testTheme = nullTheme.derive(
        rule!Frame(
            backgroundColor = frameColor,
        ),
    );
}

@("DragSlot ignores gap if the handle is hidden")
unittest {

    import std.algorithm;
    import fluid.theme;

    auto theme = nullTheme.derive(
        rule!DragSlot(gap = 4),
    );
    auto content = label("a");
    auto slot = dragSlot(content);
    auto root = testSpace(theme, slot);
    slot.handle.hide();
    root.draw();
    assert(slot.getMinSize == content.getMinSize);
    root.drawAndAssert(
        content.drawsImage(content.text.texture.chunks[0].image)
            .at(0, 0)
    );

}

@("DragSlot can be dragged")
unittest {

    auto content = label(.ignoreMouse, "a");
    auto slot = dragSlot(.nullTheme, content);
    auto hover = hoverChain();
    auto root = chain(
        hover,
        overlayChain(),
        slot
    );

    root.draw();
    hover.point(4, 4)
        .then((a) {
            assert(a.isHovered(slot));
            assert(!slot.dragAction);
            a.press(false);
            return a.move(100, 100);
        })
        .then((a) {
            a.press(false);
            assert(a.isHovered(slot));
            assert(slot.dragAction.offset == Vector2(96, 96));
            return a.move(50, -50);
        })
        .then((a) {
            a.press(false);
            assert(slot.dragAction.offset == Vector2(46, -54));
            return root.nextFrame;
        })
        .runWhileDrawing(root);

    assert(!slot.dragAction);

}

@("DragSlot allows the dragged node to be resized while dragged")
unittest {

    auto content = resizable(Vector2(10, 10));
    auto slot = dragSlot(.nullTheme, content);
    auto hover = hoverChain();
    auto root = chain(
        hover,
        overlayChain(),
        slot
    );

    root.draw();
    hover.point(5, 5)
        .then((a) {
            assert(a.isHovered(slot));
            assert(!slot.dragAction);
            assert(content.getMinSize == Vector2(10, 10));
            a.press(false);
            return a.move(105, 5);
        })

        // Resize the node
        .then((a) {
            a.press(false);
            content.size = Vector2(0, 0);
            content.updateSize();
            assert(slot.dragAction.offset == Vector2(100, 0));
            assert(content.getMinSize == Vector2(10, 10));
            return a.move(205, 5);
        })
        .then((a) {
            a.press(false);
            assert(slot.dragAction.offset == Vector2(200, 0));
            assert(content.getMinSize == Vector2(0, 0));
            return a.move(305, 5);
        })
        .then((a) {
            a.press(false);
            assert(slot.dragAction.offset == Vector2(300, 0));
            assert(content.getMinSize == Vector2(0, 0));
            return root.nextFrame;
        })
        .runWhileDrawing(root);

    assert(!slot.dragAction);
    assert(content.getMinSize == Vector2(0, 0));

}

@("DragSlot contents can load I/O systems while dragged")
unittest {

    static class IOTracker : Node {

        HoverIO hoverIO;
        CanvasIO canvasIO;

        override void resizeImpl(Vector2) {
            use(hoverIO);
            use(canvasIO);
        }

        override void drawImpl(Rectangle, Rectangle) {

        }

    }

    alias ioTracker = nodeBuilder!IOTracker;

    auto slot = dragSlot();
    auto overlay = overlayChain();
    auto hover = hoverChain();
    auto root = testSpace(
        chain(
            focusChain(),
            hover,
            overlay,
            slot,
        )
    );

    root.drawAndAssert(
        overlay.drawsChild(slot),
    );
    assert(slot.hoverIO.opEquals(hover));
    auto action = hover.point(0, 0);
    slot.drag(action.pointer);
    assert(slot.dragAction);
    root.drawAndAssert(
        overlay.drawsChild(slot.overlay),
        slot.isDrawn,
    );
    root.drawAndAssertFailure(
        overlay.drawsChild(slot),
    );
    assert(slot.dragAction);
    assert(slot.hoverIO.opEquals(hover));

    // Place the tracker in the slot, continue dragging
    auto tracker = ioTracker();
    slot = tracker;
    slot.drag(action.pointer);
    root.drawAndAssert(
        overlay.drawsChild(slot.overlay),
        slot.value.isDrawn,
    );
    assert(slot.dragAction);
    assert(slot.hoverIO.opEquals(hover));
    assert(slot.canvasIO.opEquals(root));
    assert(tracker.hoverIO.opEquals(hover));
    assert(tracker.canvasIO.opEquals(root));

}

@("Droppable nodes can be nested")
unittest {

    DragSlot slot;
    Frame inner;
    Label[2] dummies;

    const targets = [
        Vector2(0, 450),  // Control sample
        Vector2(0, 0),    // Drop into outer
        Vector2(0, 300),  // Drop into inner
    ];

    foreach (index, dropTarget; targets) {

        auto outer = sizeLock!vframe(
            .layout!(1, "fill"),
            .sizeLimit(600, 600),
            .acceptDrop,
            dummies[0] = label(
                .layout!1,
                "Dummy 1",
            ),
            inner = vframe(
                .layout!(1, "fill"),
                .acceptDrop,
                dummies[1] = label(
                    .layout!1,
                    "Dummy 2"
                ),
                slot = sizeLock!dragSlot(
                    .layout!1,
                    .sizeLimit(100, 100),
                    label(
                        .ignoreMouse,
                        "Drag me"
                    ),
                ),
            )
        );
        auto overlay = overlayChain(.layout!"fill");
        auto hover = hoverChain(.testTheme, .layout!"fill");
        auto root = testSpace(
            chain(hover, overlay, outer)
        );

        root.drawAndAssert(
            slot.isDrawn().at(0, 450),
        ),

        hover.point(1, 451)
            .then((a) {
                a.press(false);
                return a.move(dropTarget);
            })

            // Hover over the target
            .then((a) {
                a.press(false);
                root.draw();
                a.press(false);

                // Control sample
                if (index == 0) {
                    root.drawAndAssert(
                        dummies[0].isDrawn().at(0, 0),
                        dummies[1].isDrawn().at(0, 300),
                    );
                }
                // Drop into outer
                else if (index == 1) {
                    root.drawAndAssert(
                        dummies[0].isDrawn().at(0, 100),  // TODO correct expanding behavior
                        dummies[1].isDrawn().at(0, 400),
                    );
                }
                // Drop into inner
                else if (index == 2) {
                    root.drawAndAssert(
                        dummies[0].isDrawn().at(0, 000),
                        dummies[1].isDrawn().at(0, 400),
                    );
                }
                a.press(false);
                root.drawAndAssert(
                    overlay.drawsChild(slot.overlay),
                );
                return a.stayIdle;
            })

            // Drop it
            .then((a) {
                root.draw();  // _readyToDrop = true
                root.draw();  // drop()

                if (index == 0) {
                    root.drawAndAssert(
                        dummies[0].isDrawn().at(0,   0),
                        dummies[1].isDrawn().at(0, 300),
                        slot      .isDrawn().at(0, 450),
                    );
                }
                // Drop into outer
                else if (index == 1) {
                    root.drawAndAssert(
                        slot      .isDrawn().at(0,   0),
                        dummies[0].isDrawn().at(0, 200),
                        dummies[1].isDrawn().at(0, 400),
                    );
                }
                // Drop into inner
                else if (index == 2) {
                    root.drawAndAssert(
                        dummies[0].isDrawn().at(0,   0),
                        slot      .isDrawn().at(0, 300),
                        dummies[1].isDrawn().at(0, 450),
                    );
                }
            })
            .runWhileDrawing(root, 4);

    }

}

@("DragSlot cancels movement if dropped out of area")
unittest {

    auto slot = dragSlot(
        label(.ignoreMouse, "Drag me"),
    );
    auto hover = hoverChain(vframe(slot));
    auto root = testSpace(
        .testTheme,
        .layout!"fill",
        overlayChain(hover),
    );

    hover.point(1, 1)
        .then((a) {
            a.click(false);
            return a.move(100, 100);
        })
        .then((a) {
            assert(slot.isDragged);
            a.click(true);
            return a.stayIdle;
        })
        .runWhileDrawing(root, 4);

}
