module nodes.hover_transform;

import fluid;
import fluid.future.pipe;

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

@("HoverTransform supports scrolling")
unittest {

    auto tracker = sizeLock!scrollTracker(
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

    hover.point(75, 25).scroll(0, 40)
        .then((a) {
            assert(tracker.lastScroll == Vector2(0, 40));
            assert(tracker.totalScroll == Vector2(0, 40));
        })
        .runWhileDrawing(root, 2);

    hover.point(25, 25).scroll(0, 60)
        .then((a) {
            assert(tracker.lastScroll == Vector2(0, 40));
            assert(tracker.totalScroll == Vector2(0, 40));
        })
        .runWhileDrawing(root, 2);

}

@("HoverTransform children can create pointers")
unittest {

    auto tracker1 = sizeLock!hoverTracker(
        .sizeLimit(50, 50),
    );
    auto tracker2 = sizeLock!hoverTracker(
        .sizeLimit(50, 50),
    );
    auto innerDevice = myHover();
    auto outerDevice = myHover();
    auto transform = hoverTransform(
        .layout!"fill",
        Rectangle(50, 0, 100, 50),
        hspace(
            tracker1,
            tracker2,
            innerDevice,
        ),
    );
    auto hover = hoverChain();
    auto root = chain(
        inputMapChain(.layout!"fill"),
        hover,
        vspace(
            .layout!"fill",
            transform,
            outerDevice,
        ),
    );

    // Point both pointers at the same spot
    outerDevice.pointers = [
        outerDevice.makePointer(0, Vector2(75, 25)),
    ];
    innerDevice.pointers = [
        innerDevice.makePointer(0, Vector2(75, 25)),
    ];
    root.draw();
    root.draw();  // 1 frame delay; need to wait for draw

    const outerPointerID = hover.armedPointerID(outerDevice.pointers[0].id);
    const innerPointerID = hover.armedPointerID(innerDevice.pointers[0].id);
    auto outerPointer = hover.fetch(outerPointerID);
    auto innerPointer = hover.fetch(innerPointerID);

    // `outerDevice`, just like in other tests, gets transformed and hits `tracker1`.
    assert(hover.hoverOf(outerPointer).opEquals(transform));
    assert(transform.hoverOf(outerPointer).opEquals(tracker1));

    // `innerDevice` exists within the transformed coordinate system, so, within the system, its
    // position will stay unchanged. It should hit `tracker2`
    assert(hover.hoverOf(innerPointer).opEquals(transform));
    assert(transform.hoverOf(innerPointer).opEquals(tracker2));

    // Press the inner device
    innerDevice.emit(0, MouseIO.press.left);
    root.draw();
    assert(tracker1.pressCount == 0);
    assert(tracker2.pressCount == 1);

}

@("HoverTransform supports iterating on hovered items")
unittest {

    auto tracker1 = sizeLock!hoverTracker(
        .sizeLimit(50, 50),
    );
    auto tracker2 = sizeLock!hoverTracker(
        .sizeLimit(50, 50),
    );
    auto tracker3 = sizeLock!hoverTracker(
        .sizeLimit(50, 50),
    );
    auto transform = hoverTransform(Rectangle(50, 0, 200, 50));
    auto hover = hoverChain();
    auto root = chain(
        inputMapChain(.layout!"fill"),
        hover,
        transform,
        hspace(
            tracker1,
            sizeLock!vspace(
                .sizeLimit(50, 50)
            ),
            tracker2,
            tracker3,
        ),
    );

    auto action1 = hover.point( 75, 25);
    auto action2 = hover.point(125, 25);
    auto action3 = hover.point(175, 25);

    join(action1, action2, action3)
        .runWhileDrawing(root, 2);

    assert(action1.isHovered(transform));
    assert(action2.isHovered(transform));
    assert(action3.isHovered(transform));
    action1.stayIdle;  // tracker1
    action2.stayIdle;  // blank space
    action3.stayIdle;  // tracker2

    int matched1, matched2;

    foreach (Hoverable hoverable; transform) {
        if (hoverable.opEquals(tracker1)) matched1++;
        else if (hoverable.opEquals(tracker2)) matched2++;
        else assert(false);
    }

    assert(matched1 == 1);
    assert(matched2 == 1);

}
