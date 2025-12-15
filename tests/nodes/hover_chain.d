module nodes.hover_chain;

import std.array;
import fluid;

@safe:

alias myHover = nodeBuilder!MyHover;

class MyHover : Node, MouseIO {

    HoverIO hoverIO;
    HoverPointer[] pointers;

    inout(HoverPointer) makePointer(int number, Vector2 position, bool isDisabled = false) inout {
        return inout HoverPointer(this, number, position, Vector2(), isDisabled);
    }

    void emit(int number, InputEvent event) {

        foreach (pointer; pointers) {
            if (pointer.number != number) continue;
            hoverIO.emitEvent(pointer, event);
            return;
        }

        assert(false);

    }

    override void resizeImpl(Vector2 space) {
        require(hoverIO);
        loadPointers();
        minSize = Vector2();
    }

    override void drawImpl(Rectangle, Rectangle) {
        loadPointers();
    }

    void loadPointers() {

        foreach (ref pointer; pointers) {
            load(hoverIO, pointer);
        }

    }

}

alias hoverTracker = nodeBuilder!HoverTracker;

class HoverTracker : Node, Hoverable {

    mixin enableInputActions;

    HoverIO hoverIO;

    int hoverImplCount;
    int pressHeldCount;
    int pressCount;

    HoverPointer lastPointer;
    Appender!(HoverPointer[]) pointers;

    override void resizeImpl(Vector2) {
        require(hoverIO);
        minSize = Vector2();
    }

    override void drawImpl(Rectangle, Rectangle) {
        pointers.clear();
        foreach (HoverPointer pointer; hoverIO) {
            pointers ~= pointer;
        }
    }

    override bool blocksInput() const {
        return isDisabled || isDisabledInherited;
    }

    override bool hoverImpl(HoverPointer) {
        assert(!blocksInput);
        hoverImplCount++;
        return false;
    }

    override bool isHovered() const {
        return hoverIO.isHovered(this);
    }

    alias opEquals = typeof(super).opEquals;

    override bool opEquals(const Object other) const {
        return super.opEquals(other);
    }

    @(FluidInputAction.press, WhileHeld)
    void pressHeld(HoverPointer pointer) {
        assert(!blocksInput);
        pressHeldCount++;
        lastPointer = pointer;
    }

    @(FluidInputAction.press)
    void press(HoverPointer pointer) {
        assert(!blocksInput);
        pressCount++;
        lastPointer = pointer;
    }

}

alias scrollTracker = nodeBuilder!ScrollTracker;

class ScrollTracker : Frame, HoverScrollable {

    bool disableScroll;
    Vector2 totalScroll;
    Vector2 lastScroll;

    this(Node[] nodes...) {
        super(nodes);
    }

    alias opEquals = Frame.opEquals;

    override bool opEquals(const Object other) const {
        return super.opEquals(other);
    }

    override bool canScroll(const HoverPointer) const {
        return !disableScroll;
    }

    override Rectangle shallowScrollTo(const Node, Rectangle, Rectangle childBox) {
        return childBox;
    }

    override bool scrollImpl(HoverPointer pointer) {
        totalScroll += pointer.scroll;
        lastScroll   = pointer.scroll;
        return true;
    }

}

@("HoverChain assigns unique IDs for each pointer number")
unittest {

    MyHover device;

    auto root = hoverChain(
        device = myHover(),
    );

    device.pointers = [
        device.makePointer(0, Vector2(1, 1)),
        device.makePointer(1, Vector2(1, 1)),
    ];
    root.draw();

    assert(device.pointers[0].id != device.pointers[1].id);

}

@("HoverChain assigns unique IDs for different devices")
unittest {

    MyHover firstDevice, secondDevice;

    auto root = hoverChain(
        vspace(
            firstDevice  = myHover(),
            secondDevice = myHover()
        ),
    );

    firstDevice.pointers = [
        firstDevice.makePointer(0, Vector2(1, 1)),
    ];
    secondDevice.pointers = [
        secondDevice.makePointer(0, Vector2(1, 1)),
    ];
    root.draw();

    assert(firstDevice.pointers[0].id != secondDevice.pointers[0].id);

}

@("HoverChain can list hovered nodes")
unittest {

    MyHover device;
    Button one, two;

    auto root = hoverChain(
        .nullTheme,
        sizeLock!vspace(
            .sizeLimit(300, 300),
            device = myHover(),
            one    = button(.layout!(1, "fill"), "One", delegate { }),
                     vframe(.layout!(1, "fill")),
            two    = button(.layout!(1, "fill"), "Two", delegate { }),
        ),
    );

    root.draw();
    assert(!root.hovers);
    assert(!one.isHovered);
    assert(!two.isHovered);

    device.pointers = [
        device.makePointer(0, Vector2(0, 0)),
    ];
    root.draw();
    root.draw();
    assert(root.hovers(one));
    assert(root.hoversOnly([one]));
    assert(one.isHovered);
    assert(!two.isHovered);

    device.pointers = [
        device.makePointer(0, Vector2(0, 120)),
    ];
    root.draw();
    root.draw();
    assert(!root.hovers());

    device.pointers = [
        device.makePointer(0, Vector2(0, 220)),
    ];
    root.draw();
    root.draw();
    assert(root.hovers());
    assert(root.hoversOnly([two]));
    assert(!one.isHovered);
    assert(two.isHovered);

}

@("Opaque nodes block hover")
unittest {

    MyHover device;
    Button btn;
    Frame frame;

    auto root = hoverChain(
        vspace(
            device = myHover(),
            onionFrame(
                .layout!"fill",
                btn   = button("One", delegate { }),
                frame = vframe(.layout!"fill"),
            ),
        ),
    );

    device.pointers = [
        device.makePointer(0, Vector2(20, 20)),
    ];
    root.draw();
    root.draw();
    assert(!root.hovers);

    frame.hide();
    root.draw();
    root.draw();
    assert(root.hovers(btn));
    assert(btn.isHovered);

    frame.show();
    root.draw();
    root.draw();
    assert(!root.hovers);
    assert(!btn.isHovered);

}

@("HoverChain triggers input actions")
unittest {

    MyHover device;
    Button btn;
    HoverChain hover;
    int pressCount;

    auto map = InputMapping();
    map.bindNew!(FluidInputAction.press)(MouseIO.codes.left);

    auto root = inputMapChain(
        .nullTheme,
        map,
        hover = hoverChain(
            vspace(
                device = myHover(),
                btn    = button("One", delegate { pressCount++; }),
            ),
        ),
    );

    device.pointers = [
        device.makePointer(0, Vector2(10, 10)),
    ];
    root.draw();
    root.draw();

    assert(hover.hovers(btn));
    assert(pressCount == 0);

    device.emit(0, MouseIO.release.left);

    assert(pressCount == 0);

    root.draw();
    assert(pressCount == 1);

    root.draw();
    assert(pressCount == 1);

}

@("HoverChain actions won't apply if hover changes")
unittest {

    MyHover device;
    HoverChain hover;

    int onePressed;
    int twoPressed;

    auto map = InputMapping();
    map.bindNew!(FluidInputAction.press)(MouseIO.codes.left);

    auto root = inputMapChain(
        map,
        hover = hoverChain(
            .nullTheme,
            sizeLock!vspace(
                .sizeLimit(400, 400),
                device = myHover(),
        		button(.layout!(1, "fill"), "One", delegate { onePressed++; }),
                button(.layout!(1, "fill"), "Two", delegate { twoPressed++; }),
            ),
        )
    );

    device.pointers = [
        device.makePointer(0, Vector2(100, 100)),
        device.makePointer(1, Vector2(300, 300)),
    ];
    root.draw();

    // Hold both — no input action is necessary
    device.emit(0, MouseIO.hold.left);
    device.emit(1, MouseIO.hold.left);
    root.draw();

    // Move them
    device.pointers = [
        device.makePointer(0, Vector2(100, 300)),
        device.makePointer(1, Vector2(300, 100)),
    ];
    device.emit(0, MouseIO.hold.left);
    device.emit(1, MouseIO.hold.left);
    root.draw();

    assert(onePressed == 0);
    assert(twoPressed == 0);

    // Press them
    device.emit(0, MouseIO.release.left);
    device.emit(1, MouseIO.release.left);
    root.draw();
    hover.runInputAction!(FluidInputAction.press)(device.pointers[0]);
    hover.runInputAction!(FluidInputAction.press)(device.pointers[1]);

    assert(onePressed == 0);
    assert(twoPressed == 0);

    // Move outside of the canvas
    device.pointers = [
        device.makePointer(0, Vector2(500, 500)),
    ];
    device.emit(0, MouseIO.hold.left);
    root.draw();
    device.emit(0, MouseIO.hold.left);
    root.draw();
    device.emit(0, MouseIO.release.left);
    root.draw();
    assert(onePressed == 0);

}

@("HoverChain triggers hover events, even if moved")
unittest {

    MyHover device;
    HoverChain hover;
    HoverTracker tracker1, tracker2;

    auto map = InputMapping();
    map.bindNew!(FluidInputAction.press)(MouseIO.codes.left);

    auto root = inputMapChain(
        map,
        hover = hoverChain(
            .nullTheme,
            sizeLock!vspace(
                .sizeLimit(400, 400),
                device   = myHover(),
                tracker1 = hoverTracker(.layout!(1, "fill")),
                tracker2 = hoverTracker(.layout!(1, "fill")),
            ),
        )
    );

    device.pointers = [
        device.makePointer(0, Vector2(100, 100)),
    ];
    root.draw();
    assert(tracker1.hoverImplCount == 1);
    assert(tracker1.pressHeldCount == 0);
    assert(tracker1.pressCount == 0);
    assert(tracker2.hoverImplCount == 0);

    // Hover
    root.draw();
    assert(tracker1.hoverImplCount == 2);
    assert(tracker1.pressHeldCount == 0);

    // Hold
    device.emit(0, MouseIO.hold.left);
    root.draw();
    assert(tracker1.hoverImplCount == 2);  // pressHeld overrides this call
    assert(tracker1.pressHeldCount == 1);

    device.emit(0, MouseIO.hold.left);
    root.draw();
    assert(tracker1.hoverImplCount == 2);
    assert(tracker1.pressHeldCount == 2);
    assert(tracker1.pressCount == 0);
    assert(tracker2.hoverImplCount == 0);

    // Press
    device.emit(0, MouseIO.press.left);
    root.draw();
    assert(tracker1.hoverImplCount == 2);
    assert(tracker1.pressHeldCount == 3);
    assert(tracker1.pressCount == 1);
    assert(tracker2.hoverImplCount == 0);

    // Move & press
    device.pointers = [
        device.makePointer(0, Vector2(100, 300)),
    ];
    device.emit(0, MouseIO.hold.left);
    root.draw();
    assert(tracker1.hoverImplCount == 2);
    assert(tracker1.pressHeldCount == 4);
    assert(tracker2.hoverImplCount == 0);
    assert(tracker2.pressHeldCount == 0);

    device.emit(0, MouseIO.hold.left);
    root.draw();
    assert(tracker1.hoverImplCount == 2);  // Hover still calls the old tracker
    assert(tracker1.pressHeldCount == 5);

    device.emit(0, MouseIO.press.left);
    root.draw();
    assert(tracker1.hoverImplCount == 3);
    assert(tracker1.pressHeldCount == 5);
    assert(tracker1.pressCount == 1);
    assert(tracker2.hoverImplCount == 0);
    assert(tracker2.pressHeldCount == 0);
    assert(tracker2.pressCount == 0);      // The press isn't registered.

    root.draw();
    assert(tracker2.hoverImplCount == 1);  // Hover only registers after release

    // Unrelated input actions cannot trigger press
    hover.runInputAction!(FluidInputAction.press)(device.pointers[0]);
    assert(tracker2.pressCount == 1);
    hover.runInputAction!(FluidInputAction.contextMenu)(device.pointers[0]);
    assert(tracker2.pressCount == 1);
    assert(tracker2.hoverImplCount == 1);

}

@("HoverChain runs hoverImpl if ActionIO is absent")
unittest {

    MyHover device;
    HoverChain hover;
    HoverTracker tracker;

    auto root = hover = hoverChain(
        .nullTheme,
        sizeLock!vspace(
            .sizeLimit(400, 400),
            device  = myHover(),
            tracker = hoverTracker(.layout!(1, "fill")),
        ),
    );

    device.pointers = [
        device.makePointer(0, Vector2(10, 10)),
    ];
    root.draw();
    assert(tracker.hoverImplCount == 1);

}

@("HoverChain doesn't call input handlers on disabled nodes")
unittest {

    MyHover device;
    HoverTracker inaccessibleTracker, mainTracker;

    auto root = hoverChain(
        .layout!(1, "fill"),
        vspace(
            .layout!(1, "fill"),
            device = myHover(),
            onionFrame(
                .layout!(1, "fill"),
                inaccessibleTracker = hoverTracker(),
                mainTracker         = hoverTracker(.layout!"fill")
            ),
        ),
    );

    device.pointers = [
        device.makePointer(0, Vector2(100, 100)),
    ];
    root.draw();
    assert(mainTracker.isHovered);
    assert(mainTracker.hoverImplCount == 1);
    assert(inaccessibleTracker.hoverImplCount == 0);

    // Disable the tracker; it shouldn't take hoverImpl, but it should continue to block
    mainTracker.disable();
    root.draw();
    assert(mainTracker.hoverImplCount == 1);
    assert(inaccessibleTracker.hoverImplCount == 0);

    // Press it
    root.emitEvent(device.pointers[0], MouseIO.release.left);
    root.draw();
    assert(mainTracker.hoverImplCount == 1);
    assert(mainTracker.pressCount == 0);
    assert(inaccessibleTracker.hoverImplCount == 0);
    assert(inaccessibleTracker.pressCount == 0);

}

@("HoverChain won't call handlers if disability status changes")
unittest {

    MyHover device;
    HoverTracker tracker;

    auto root = hoverChain(
        .layout!"fill",
        vspace(
            .layout!"fill",
            device = myHover(),
            tracker = hoverTracker(.layout!(1, "fill"))
        ),
    );

    device.pointers = [
        device.makePointer(0, Vector2(100, 100)),
    ];
    root.draw();

    // Hold the left button now
    root.runInputAction!(FluidInputAction.press)(device.pointers[0], false);
    root.draw();
    assert(tracker.isHovered);
    assert(tracker.pressHeldCount == 1);

    // Block the button and press it
    tracker.disable();
    root.runInputAction!(FluidInputAction.press)(device.pointers[0], true);
    root.draw();
    assert(tracker.isHovered);
    assert(tracker.pressHeldCount == 1);
    assert(tracker.pressCount == 0);

}

@("HoverChain fires scroll events for scrollable nodes")
unittest {

    ScrollTracker tracker;
    Button btn;

    auto hover = hoverChain(
        .layout!"fill",
        tracker = scrollTracker(
            .layout!(1, "fill"),
            btn = button(
                .layout!(1, "fill"),
                "Do not press me",
                delegate {
                    assert(false);
                }
            ),
        ),
    );
    auto root = hover;

    hover.point(50, 50).scroll(0, 10)
        .then((a) {
            assert(a.currentHover && a.currentHover.opEquals(btn));
            assert(a.currentScroll && a.currentScroll.opEquals(tracker));
            assert(tracker.totalScroll == Vector2(0, 10));
            assert(tracker.lastScroll == Vector2(0, 10));

            return a.scroll(5, 20);
        })
        .then((a) {
            assert(a.currentHover && a.currentHover.opEquals(btn));
            assert(a.currentScroll && a.currentScroll.opEquals(tracker));
            assert(tracker.lastScroll == Vector2(5, 20));
            assert(tracker.totalScroll == Vector2(5, 30));
        })
        .runWhileDrawing(root, 3);

}

@("HoverChain supports touchscreen scrolling")
unittest {

    // Try the same motion without holding the scroll (like a mouse)
    // and then while holding (like a touchscreen)
    foreach (testHold; [false, true]) {

        ScrollTracker targetTracker, dummyTracker;

        auto hover = hoverChain(
            .layout!"fill",
            sizeLock!vspace(
                .sizeLimit(100, 100),
                targetTracker = scrollTracker(
                    .layout!(2, "fill"),
                ),
                dummyTracker = scrollTracker(
                    .layout!(1, "fill"),
                ),
            ),
        );
        auto root = hover;

        hover.point(50, 25)
            .then((a) {

                assert(a.currentScroll.opEquals(targetTracker));

                // Hold the left mouse button
                a.press(false);
                return a.move(50, 75).holdScroll(0, -25, testHold);

            })
            .then((a) {

                if (testHold)
                    assert(a.currentScroll.opEquals(targetTracker));
                else
                    assert(a.currentScroll.opEquals(dummyTracker));

                // Release the mouse button
                a.press;
                return a.holdScroll(0, -25, testHold);

            })
            .runWhileDrawing(root);

        if (testHold) {
            assert(targetTracker.totalScroll.y == -50);
            assert(dummyTracker.totalScroll.y  ==   0);
        }
        else {
            assert(targetTracker.totalScroll.y ==   0);
            assert(dummyTracker.totalScroll.y  == -50);
        }

    }

}

@("Held scroll counts as a single motion for canScroll() in HoverChain")
unittest {

    // Compare differences between held and hovered scroll
    foreach (testHold; [false, true]) {

        ScrollTracker outerTracker, innerTracker;

        auto hover = hoverChain(
            sizeLock!vspace(
                .sizeLimit(100, 100),
                outerTracker = scrollTracker(
                    .layout!(1, "fill"),
                    innerTracker = scrollTracker(
                        .layout!(1, "fill"),
                    ),
                ),
            ),
        );
        auto root = hover;

        hover.point(50, 50)
            .then((a) {
                assert(a.currentScroll.opEquals(innerTracker));
                return a.holdScroll(0, -20, testHold);
            })
            // Pretend innerTracker has reached its limit for scrolling
            .then((a) {
                assert(a.currentScroll.opEquals(innerTracker));
                innerTracker.disableScroll = true;
                return a.holdScroll(0, -10, testHold);
            })
            .then((a) {
                if (testHold) {
                    assert(a.currentScroll.opEquals(innerTracker));
                }
                else {
                    assert(a.currentScroll.opEquals(outerTracker));
                }
            })
            .runWhileDrawing(root, 3);

        // A held scroll counts as a single motion, so it shouldn't test canScroll during the second frame
        if (testHold) {
            assert(innerTracker.totalScroll == Vector2(0, -30));
            assert(outerTracker.totalScroll == Vector2(0,   0));
        }

        // If not held, the motions are separate, so outerTracker should get the second part
        else {
            assert(innerTracker.totalScroll == Vector2(0, -20));
            assert(outerTracker.totalScroll == Vector2(0, -10));
        }

    }

}

@("Multiple pointers can be created in HoverChain at once")
unittest {

    auto hover = hoverChain();
    auto root = hover;

    // Resize first
    root.draw();

    HoverPointer pointer1;
    pointer1.number = 1;
    pointer1.position = Vector2(10, 10);
    hover.loadTo(pointer1);

    HoverPointer pointer2;
    pointer2.number = 2;
    pointer2.position = Vector2(20, 20);
    hover.loadTo(pointer2);
    root.draw();

    assert(hover.fetchPointer(pointer1.id).position == Vector2(10, 10));
    assert(hover.fetchPointer(pointer2.id).position == Vector2(20, 20));

}

@("Pressing a node switches focus")
unittest {

    Button button1, button2;

    auto focus = focusChain();
    auto hover = hoverChain();
    auto root = chain(
        focus,
        hover,
        sizeLock!vspace(
            .sizeLimit(100, 100),
            .nullTheme,
            button1 = button(.layout!(1, "fill"), "One", delegate { }),
            button2 = button(.layout!(1, "fill"), "Two", delegate { }),
        ),
    );

    root.draw();

    // Hover the first button; focus should stay the same
    hover.point(50, 25)
        .then((a) {
            assert(a.isHovered(button1));
            assert(focus.currentFocus is null);

            // Press to change focus
            a.press();
            return a.stayIdle;
        })
        .then((a) {
            assert(a.isHovered(button1));
            assert(focus.isFocused(button1));

            // Move onto the other button, focus should stay the same
            a.press();
            return a.move(50, 75);
        })
        .then((a) {
            assert(a.isHovered(button1));
            assert(focus.isFocused(button1));

            a.press();

        })
        .runWhileDrawing(root);

    assert(focus.isFocused(button1));

}

@("Pressing a non-focusable node clears focus")
unittest {

    Button targetButton;
    Frame filler;

    auto focus = focusChain();
    auto hover = hoverChain();
    auto root = chain(
        focus,
        hover,
        sizeLock!vspace(
            .sizeLimit(100, 100),
            .nullTheme,
            filler = vframe(.layout!(1, "fill")),
            targetButton = button(.layout!(1, "fill"), "Target", delegate { }),
        ),
    );

    root.draw();
    focus.currentFocus = targetButton;

    // Hover the space; focus should stay the same
    hover.point(50, 25)
        .then((a) {
            assert(!a.isHovered(targetButton));
            assert(focus.currentFocus.opEquals(targetButton));

            // Press to change focus
            a.press();
            return a.stayIdle;
        })
        .then((a) {
            assert(!a.isHovered(targetButton));
            assert(focus.currentFocus is null);

            // Move onto the button, focus should remain empty
            a.press();
            return a.move(50, 75);
        })
        .then((a) {
            assert(!a.isHovered(targetButton));
            assert(focus.currentFocus is null);

            a.press();

        })
        .runWhileDrawing(root);

    assert(focus.currentFocus is null);

}

@("Input event handlers receive negative pointer IDs from HoverChain")
unittest {

    auto tracker = sizeLock!hoverTracker(
        .sizeLimit(100, 100),
    );
    auto hover = hoverChain(tracker);
    auto root = chain(
        inputMapChain(),
        hover,
    );

    // Try two pointers:
    // First pointer should be ID 0, armed ID -1,
    // Second pointer should be ID 1, armed ID -2
    foreach (int id, armedID; [-1, -2]) {

        // Setup the pointer and click
        auto action = hover.point(50, 50);
        action.runWhileDrawing(root);
        hover.emitEvent(action.pointer, MouseIO.press.left);
        root.draw();

        assert(action.pointer.id == id);
        assert(tracker.pressCount == 1);
        assert(tracker.lastPointer.id == armedID);

        // Try upadting the data
        action.move(20, 20);
        assert(hover.fetchPointer(id).position == Vector2(20, 20));
        assert(hover.fetchPointer(armedID).position == Vector2(50, 50));

        tracker.pressCount = 0;

    }

}

@("HoverChain correctly receives scroll data from node inside")
unittest {

    static class IncrementalScroller : Node, MouseIO {

        HoverIO hoverIO;
        HoverPointer pointer;
        int value;

        override void resizeImpl(Vector2) {
            require(hoverIO);
            pointer.device = this;
            minSize = Vector2(0, 0);
        }

        override void drawImpl(Rectangle, Rectangle) {
            pointer.position = Vector2(0, 0);
            pointer.scroll = Vector2(0, ++value);
            load(hoverIO, pointer);
        }

    }

    alias incrementalScroller = nodeBuilder!IncrementalScroller;

    auto automaton = incrementalScroller();
    auto tracker = sizeLock!scrollTracker(
        .sizeLimit(10, 10),
    );
    auto hover = hoverChain(
        vspace(tracker, automaton),
    );
    auto root = testSpace(hover);

    // One frame to find the node
    root.draw();
    assert(tracker.lastScroll.y == 0);
    assert(tracker.totalScroll.y == 0);

    root.draw();
    assert(tracker.lastScroll.y == 1);
    assert(tracker.totalScroll.y == 1);

    root.draw();
    assert(tracker.lastScroll.y == 2);
    assert(tracker.totalScroll.y == 3);

}

@("HoverChain exposes all active pointers")
unittest {

    auto hover = hoverChain();
    auto action1 = hover.point(10, 20);
    auto action2 = hover.point(20, 10);

    size_t index;
    foreach (HoverPointer pointer; hover) {
        if (index++ == 0) {
            assert(pointer == action1.pointer);
            assert(pointer != action2.pointer);
        }
        else {
            assert(pointer != action1.pointer);
            assert(pointer == action2.pointer);
        }
    }

}

@("HoverChain's HoverPointer iterator uses armed pointers when used while drawing")
unittest {

    auto tracker = hoverTracker();
    auto hover = hoverChain(tracker);
    auto action1 = hover.point(10, 20);
    auto action2 = hover.point(20, 10);

    hover.draw();

    assert(tracker.pointers[][0].id == hover.armedPointerID(action1.pointer.id));
    assert(tracker.pointers[][1].id == hover.armedPointerID(action2.pointer.id));

    foreach (HoverPointer pointer; hover) {
        assert(pointer.id == hover.normalizedPointerID(pointer.id));
        assert(pointer.id != hover.armedPointerID(pointer.id));
    }

}

@("Buttons can change focus when pressed https://git.samerion.com/Samerion/Fluid/issues/451")
unittest {
    auto otherButton = button("Focusable", delegate { });
    auto targetButton = sizeLock!button(
        .sizeLimit(100, 100),
        "Hello",
        delegate {
            otherButton.focus();
        }
    );
    auto hover = hoverChain(
        vspace(
            targetButton,
            otherButton,
        ),
    );
    auto focus = focusChain(hover);
    auto root = testSpace(focus);

    hover
        .point(50, 50)
        .then((action) {
            assert(hover.isHovered(targetButton));
            action.press();
            return action.stayIdle;
        })
        .then((action) {
            assert(hover.isHovered(targetButton));
            assert(focus.isFocused(otherButton));
            return action.stayIdle;
        })
        .runWhileDrawing(root);

    assert(hover.isHovered(targetButton));
    assert(focus.isFocused(otherButton));
}
