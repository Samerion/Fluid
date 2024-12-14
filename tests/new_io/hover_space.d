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
