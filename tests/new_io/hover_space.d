module new_io.hover_space;

import std.array;
import fluid;

@safe:

alias myHover = nodeBuilder!MyHover;

class MyHover : Node, MouseIO {

    HoverIO hoverIO;
    Pointer[] pointers;

    inout(Pointer) makePointer(int number, Vector2 position, bool isDisabled = false) inout {
        return inout Pointer(this, number, position, isDisabled);
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

    override bool hoverImpl() {
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
        pressHeldCount++;
    }

    @(FluidInputAction.press)
    void press() {
        pressCount++;
    }

}

@("HoverSpace assigns unique IDs for each pointer number")
unittest {

    MyHover device;

    auto root = hoverSpace(
        device = myHover(),
    );

    device.pointers = [
        device.makePointer(0, Vector2(1, 1)),
        device.makePointer(1, Vector2(1, 1)),
    ];
    root.draw();

    assert(device.pointers[0].id != device.pointers[1].id);

}

@("HoverSpace assigns unique IDs for different devices")
unittest {

    MyHover firstDevice, secondDevice;

    auto root = hoverSpace(
        firstDevice  = myHover(),
        secondDevice = myHover()
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

@("HoverSpace can list hovered nodes")
unittest {

    MyHover device;
    Button one, two;

    auto root = sizeLock!hoverSpace(
        .nullTheme,
        .sizeLimit(300, 300),
        device = myHover(),
        one    = button(.layout!(1, "fill"), "One", delegate { }),
                 vframe(.layout!(1, "fill")),
        two    = button(.layout!(1, "fill"), "Two", delegate { }),
    );

    root.draw();
    assert(!root.hovers);

    device.pointers = [
        device.makePointer(0, Vector2(0, 0)),
    ];
    root.draw();
    root.draw();
    assert(root.hovers(one));
    assert(root.hoversOnly([one]));

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

}

@("Opaque nodes block hover")
unittest {

    MyHover device;
    Button btn;
    Frame frame;

    auto root = hoverSpace(
        .layout!"fill",
        device = myHover(),
        onionFrame(
            .layout!"fill",
            btn   = button("One", delegate { }),
            frame = vframe(.layout!"fill"),
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

    frame.show();
    root.draw();
    root.draw();
    assert(!root.hovers);

}

@("HoverSpace triggers input actions")
unittest {

    MyHover device;
    Button btn;
    HoverSpace hover;
    int pressCount;

    auto map = InputMapping();
    map.bindNew!(FluidInputAction.press)(MouseIO.codes.left);

    auto root = inputMapSpace(
        .nullTheme,
        .layout!"fill",
        map,
        hover = hoverSpace(
            .layout!"fill",
            device = myHover(),
            btn    = button("One", delegate { pressCount++; }),
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

@("HoverSpace actions won't apply if hover changes")
unittest {

    MyHover device;
    HoverSpace hover;

    int onePressed;
    int twoPressed;

    auto map = InputMapping();
    map.bindNew!(FluidInputAction.press)(MouseIO.codes.left);

    auto root = inputMapSpace(
        map,
        hover = sizeLock!hoverSpace(
            .nullTheme,
            .sizeLimit(400, 400),
            device = myHover(),
    		button(.layout!(1, "fill"), "One", delegate { onePressed++; }),
            button(.layout!(1, "fill"), "Two", delegate { twoPressed++; }),
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

@("HoverAction triggers hover events, even if moved")
unittest {

    MyHover device;
    HoverSpace hover;
    HoverTracker tracker1, tracker2;

    auto map = InputMapping();
    map.bindNew!(FluidInputAction.press)(MouseIO.codes.left);

    auto root = inputMapSpace(
        map,
        hover = sizeLock!hoverSpace(
            .nullTheme,
            .sizeLimit(400, 400),
            device   = myHover(),
            tracker1 = hoverTracker(.layout!(1, "fill")),
            tracker2 = hoverTracker(.layout!(1, "fill")),
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
    assert(tracker1.hoverImplCount == 2);  // The original tracker doesn't see hover anymore
    assert(tracker1.pressHeldCount == 4);
    assert(tracker2.hoverImplCount == 0);
    assert(tracker2.pressHeldCount == 1);  // Hover new calls the other tracker.
    assert(tracker2.pressCount == 0);

    device.emit(0, MouseIO.press.left);
    root.draw();
    assert(tracker1.hoverImplCount == 2);
    assert(tracker1.pressHeldCount == 4);
    assert(tracker1.pressCount == 1);
    assert(tracker2.hoverImplCount == 1);
    assert(tracker2.pressHeldCount == 1);
    assert(tracker2.pressCount == 0);      // The press isn't registered.

    root.draw();
    assert(tracker2.hoverImplCount == 2);

    // Unrelated input actions cannot trigger fallback
    hover.runInputAction!(FluidInputAction.press)(device.pointers[0]);
    assert(tracker2.pressCount == 1);
    hover.runInputAction!(FluidInputAction.contextMenu)(device.pointers[0]);
    assert(tracker2.pressCount == 1);
    assert(tracker2.hoverImplCount  == 2);

}

@("HoverSpace runs hoverImpl if ActionIO is absent")
unittest {

    MyHover device;
    HoverSpace hover;
    HoverTracker tracker;

    auto root = hover = sizeLock!hoverSpace(
        .nullTheme,
        .sizeLimit(400, 400),
        device  = myHover(),
        tracker = hoverTracker(.layout!(1, "fill")),
    );

    device.pointers = [
        device.makePointer(0, Vector2(10, 10)),
    ];
    root.draw();
    assert(tracker.hoverImplCount == 1);
    

    
}
