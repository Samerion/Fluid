module nodes.hover_transform;

import fluid;

import nodes.hover_chain;

@safe:

@("HoverTransform yields transformed pointers when iterated")
unittest {

    auto content = sizeLock!vspace(
        .sizeLimit(500, 500),
    );
    auto transform = hoverTransform(
        Rectangle(50, 50, 100, 100),
        content
    );
    auto hover = hoverChain(
        .layout!(1, "fill"),
        transform,
    );
    auto root = testSpace(
        hover
    );

    root.draw();

    auto action = hover.point(50, 50);
    foreach (HoverPointer pointer; transform) {
        assert(pointer.position == Vector2(0, 0));
        assert(pointer.scroll == Vector2(0, 0));
    }

    action.move(75, 150).scroll(10, 20);
    foreach (HoverPointer pointer; transform) {
        assert(pointer.position == Vector2(125, 500));
        assert(pointer.scroll == Vector2(10, 20));
    }

    hover.point(0, 0);
    auto index = 0;
    foreach (HoverPointer pointer; transform) {
        if (index++ == 0) {
            assert(pointer.position == Vector2(125, 500));
            assert(pointer.scroll == Vector2(10, 20));
        }
        else {
            assert(pointer.position == Vector2(-250, -250));
            assert(pointer.scroll == Vector2(0, 0));
        }
    }

}

@("HoverTransform can fetch and transform nodes")
unittest {

    auto transform = hoverTransform(
        Rectangle(  50,   50, 100, 100),
        Rectangle(-100, -100, 100, 100),
    );
    auto hover = hoverChain(transform);

    hover.draw();

    auto action = hover.point(56, 56).scroll(2, 3);
    auto pointer = transform.fetch(action.pointer.id);
    assert(pointer.id       == action.pointer.id);
    assert(pointer.position == Vector2(-94, -94));
    assert(pointer.scroll   == Vector2(  2,   3));

}

@("HoverTransform affects child nodes")
unittest {

    // Target's actual position is the first 50×50 rectangle
    // Transform takes events from the 50×50 rectangle next to it.
    auto tracker = sizeLock!hoverTracker(
        .sizeLimit(50, 50),
    );
    auto transform = hoverTransform(Rectangle(50, 0, 50, 50));
    auto hover = hoverChain();
    auto root = chain(
        inputMapChain(.layout!"fill"),
        hover,
        transform,
        tracker,
    );

    hover.point(75, 25)
        .then((a) {
            assert(tracker.hoverImplCount == 1);
            assert(tracker.pressHeldCount == 0);
            a.press(false);
            return a.stayIdle;
        })
        .then((a) {
            assert(tracker.hoverImplCount == 1);
            assert(tracker.pressHeldCount == 1);
            assert(tracker.pressCount == 0);
            a.press(true);
            return a.stayIdle;
        })
        .runWhileDrawing(root, 3);

    assert(tracker.hoverImplCount == 1);
    assert(tracker.pressHeldCount == 2);
    assert(tracker.pressCount == 1);

}

@("HoverTransform doesn't trigger active events when outside")
unittest {

    auto tracker = sizeLock!hoverTracker(
        .sizeLimit(50, 50),
    );
    auto transform = hoverTransform(Rectangle(50, 0, 50, 50));
    auto hover = hoverChain();
    auto root = chain(
        inputMapChain(.layout!"fill"),
        hover,
        transform,
        tracker,
    );

    root.draw();

    // Holding and clicking works inside
    hover.point(75, 25)
        .then((a) {
            assert(hover.isHovered(transform));
            assert(transform.isHovered(tracker));
            assert(tracker.hoverImplCount == 1);
            a.press();
            assert(tracker.pressHeldCount == 1);
            assert(tracker.pressCount == 1);
            return a.stayIdle;
        })
        .then((a) {
            a.press(false);
            assert(tracker.pressHeldCount == 2);
            assert(tracker.pressCount == 1);
            return a.move(25, 25);
        })

        // Outside the node, only holding works
        .then((a) {
            a.press(false);
            assert(hover.isHovered(transform));
            assert(transform.isHovered(tracker));
            assert(tracker.pressHeldCount == 3);
            assert(tracker.pressCount == 1);
            return a.stayIdle;
        })
        .then((a) {
            a.press(true);
            assert(tracker.pressHeldCount == 3);
            assert(tracker.pressCount == 1);
            assert(tracker.hoverImplCount == 1);
        })
        .runWhileDrawing(root, 5);

}
