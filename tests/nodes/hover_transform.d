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

@("HoverTransform can be nested inside a scrollable")
unittest {

    auto innerScroll = sizeLock!scrollTracker(
        .sizeLimit(100, 100),
    );
    auto transform = hoverTransform(
        .layout!(1, "fill"),
        Rectangle(250, 250, 250, 250),
        innerScroll,
    );
    auto outerScroll = sizeLock!scrollTracker(
        .sizeLimit(500, 500),
        transform,
    );
    auto hover = hoverChain(outerScroll);
    auto root = testSpace(.nullTheme, hover);

    // outer: (0, 0)–(500, 500)
    // transform spans the entire area of outer,
    // accepts input in (250, 250)–(500, 500)
    // inner: (250, 250)–(350, 350)

    // Scroll in inner
    hover.point(300, 300).scroll(1, 2)
        .then((a) {
            const armed = hover.armedPointer(a.pointer);

            assert(hover.hoverOf(a.pointer).opEquals(transform));
            assert(hover.scrollOf(a.pointer).opEquals(transform));
            assert(transform.scrollOf(armed).opEquals(innerScroll));
            assert(outerScroll.lastScroll == Vector2(0, 0));
            assert(innerScroll.lastScroll == Vector2(1, 2));

            // Scroll in outer
            return a.move(200, 200).scroll(3, 4);
        })
        .then((a) {
            assert(hover.scrollOf(a.pointer).opEquals(outerScroll));
            assert(outerScroll.lastScroll == Vector2(3, 4));
            assert(innerScroll.lastScroll == Vector2(1, 2));
        })
        .runWhileDrawing(root, 3);

}

@("HoverTransform works with scrollIntoView")
unittest {

    ScrollFrame outerFrame, innerFrame;
    Button target;

    auto ui = sizeLock!vspace(
        .sizeLimit(250, 250),
        .nullTheme,
        outerFrame = vscrollFrame(
            .layout!(1, "fill"),
            sizeLock!vspace(
                .sizeLimit(250, 250),
            ),
            hoverTransform(
                Rectangle(0, 0, 100, 100),
                innerFrame = sizeLock!vscrollFrame(
                    .sizeLimit(250, 250),
                    sizeLock!vspace(
                        .sizeLimit(250, 250),
                    ),
                    target = button("Make me visible!", delegate { }),
                    sizeLock!vspace(
                        .sizeLimit(250, 250),
                    ),
                ),
            ),
        )
    );

    auto hover = hoverChain(ui);
    auto root = testSpace(hover);

    root.drawAndAssert(
        outerFrame.isDrawn.at(0, 0, 250, 250),
        innerFrame.isDrawn.at(0, 250),
        target.isDrawn.at(0, 500),
    );
    target.scrollToTop()
        .runWhileDrawing(root, 1);
    root.drawAndAssert(
        outerFrame.isDrawn.at(0, 0, 250, 250),
        innerFrame.isDrawn.at(0, 0),
        target.isDrawn.at(0, 0),
    );

    assert(outerFrame.scroll == 250);
    assert(innerFrame.scroll == 250);


}

@("HoverTransform can switch between targets")
unittest {

    Button[2] buttons;

    auto content = resolutionOverride!vspace(
        Vector2(400, 400),
        buttons[0] = button(.layout!(1, "fill"), "One", delegate { }),
        buttons[1] = button(.layout!(1, "fill"), "One", delegate { }),
    );
    auto transform = hoverTransform(
        Rectangle(0, 0, 100, 100),
        content
    );
    auto hover = hoverChain(
        .layout!(1, "fill"),
        transform,
    );
    auto root = testSpace(hover);

    hover.point(25, 25)
        .then((a) {
            assert(transform.isHovered(buttons[0]));
            a.press();
            return a.stayIdle;
        })
        .then((a) => a.move(75, 75))
        .then((a) {
            assert(transform.isHovered(buttons[1]));
            a.press();
        })
        .runWhileDrawing(root, 4);

}

@("HoverTransform supports holding scroll")
unittest {

    auto innerButton = button(.layout!(1, "fill"), "Two", delegate { });
    auto tracker = scrollTracker(
        .layout!(1, "fill"),
        innerButton,
    );
    auto content = resolutionOverride!vspace(
        Vector2(400, 400),
        button(.layout!(1, "fill"), "One", delegate { }),
        tracker,
    );
    auto transform = hoverTransform(
        Rectangle(0, 0, 100, 100),
        content
    );
    auto hover = hoverChain(
        .layout!(1, "fill"),
        transform,
    );
    auto root = testSpace(hover);

    hover.point(75, 75).scroll(0, 25)
        .then((a) {
            const pointer = hover.armedPointer(a.pointer);
            assert(transform.scrollOf(pointer).opEquals(tracker));
            assert(tracker.lastScroll == Vector2(0, 25));
            return a.move(25, 25).holdScroll(0, 5);
        })
        .then((a) {
            const pointer = hover.armedPointer(a.pointer);
            assert(transform.scrollOf(pointer).opEquals(tracker));
            assert(tracker.lastScroll  == Vector2(0,  5));
            assert(tracker.totalScroll == Vector2(0, 30));
            return a.scroll(0, 25);
        })
        .runWhileDrawing(root, 4);

    assert(tracker.totalScroll == Vector2(0, 30));

}

// @("")
