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
