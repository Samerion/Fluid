module nodes.hover_transform;

import fluid;

import nodes.hover_chain;

@safe:

@("HoverTransform yields transformed pointers when iterated")
unittest {

    auto transform = hoverTransform(Rectangle(50, 50, 100, 100));
    auto hover = hoverChain(
        .layout!(1, "fill"),
        transform,
    );
    auto root = sizeLock!testSpace(
        .sizeLimit(500, 500),
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
        hover,
        transform,
        tracker,
    );

    hover.point(75, 50)
        .then((a) {
            assert(tracker.hoverImplCount == 1);
            assert(tracker.pressHeldCount == 0);
            a.press(false);
            return a;
        })
        .then((a) {
            assert(tracker.hoverImplCount == 1);
            assert(tracker.pressHeldCount == 1);
            assert(tracker.pressCount == 0);
            a.press(true);
            return a;
        })
        .runWhileDrawing(root);

    assert(tracker.hoverImplCount == 1);
    assert(tracker.pressHeldCount == 1);
    assert(tracker.pressCount == 1);

}
