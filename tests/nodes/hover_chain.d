module nodes.hover_chain;

import std.array;
import fluid;

@safe:

alias myHover = nodeBuilder!MyHover;

class MyHover : Node, MouseIO {

    HoverIO hoverIO;
    Pointer[] pointers;

    inout(Pointer) makePointer(int number, Vector2 position, bool isDisabled = false) inout {
        return inout Pointer(this, number, position, Vector2(), isDisabled);
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

    override void resizeImpl(Vector2) {
        require(hoverIO);
        minSize = Vector2();
    }

    override void drawImpl(Rectangle, Rectangle) {

    }

    override bool blocksInput() const {
        return isDisabled || isDisabledInherited;
    }

    override bool hoverImpl() {
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
    void pressHeld() {
        assert(!blocksInput);
        pressHeldCount++;
    }

    @(FluidInputAction.press)
    void press() {
        assert(!blocksInput);
        pressCount++;
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

    override bool canScroll(Vector2) const {
        return !disableScroll;
    }

    override Rectangle shallowScrollTo(const Node, Rectangle, Rectangle childBox) {
        return childBox;
    }

    override void scrollImpl(Vector2 scroll) {
        totalScroll += scroll;
        lastScroll   = scroll;
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
