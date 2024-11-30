module nodes.slider;

import fluid;

import std.range;

@safe:

@("[TODO] Legacy: Slider can be changed with mouse movements")
unittest {

    const size = Vector2(500, 200);
    const rect = Rectangle(0, 0, size.tupleof);

    auto io = new HeadlessBackend(size);
    auto root = slider!int(
        .layout!("fill", "start"),
        iota(1, 4)
    );

    root.io = io;
    root.draw();

    // Default value
    assert(root.index == 0);
    assert(root.value == 1);

    // Press at the center
    io.mousePosition = center(rect);
    io.press;
    root.draw();

    // This should have switched to the second value
    assert(root.index == 1);
    assert(root.value == 2);

    // Move the mouse below the bar
    io.nextFrame;
    io.mousePosition = Vector2(0, end(rect).y + 100);
    root.draw();

    // The slider should still be affected
    assert(root.index == 0);
    assert(root.value == 1);

    // Release the mouse and move again
    io.nextFrame;
    io.release;
    io.nextFrame;
    io.mousePosition = Vector2(center(rect).x, end(rect).y + 100);
    root.draw();

    // No change
    assert(root.index == 0);
    assert(root.value == 1);

    // Slider should react to input actions
    io.nextFrame;
    root.runInputAction!(FluidInputAction.scrollRight);
    root.draw();

    assert(root.index == 1);
    assert(root.value == 2);

}

