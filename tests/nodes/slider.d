module nodes.slider;

import std.range;

import fluid;

@safe:

@("Slider can be changed with mouse movements")
unittest {

    const size = Vector2(500, 200);
    const rect = Rectangle(0, 0, size.tupleof);

    auto input = sizeLock!(slider!int)(
        .sizeLimit(500, 200),
        iota(1, 4)
    );
    auto hover = hoverChain(input);
    auto root = hover;

    root.draw();

    // Default value
    assert(input.index == 0);
    assert(input.value == 1);

    // Press at the center
    hover.point(center(rect))
        .then((pointer) { 
            
            pointer.press;

            // This should have switched to the second value
            assert(input.index == 1);
            assert(input.value == 2);

            // Move the mouse below the bar
            return pointer.move(Vector2(0, end(rect).y + 100));

        })
        .then((pointer) {

            // Keep pressing
            pointer.press(false);

            // The slider should still be affected
            assert(input.index == 0);
            assert(input.value == 1);

            return pointer.stayIdle;

        })
        .then((pointer) {

            assert(input.index == 0);
            assert(input.value == 1);

            // Now the mouse should be released
            return pointer.move(Vector2(center(rect).x, end(rect).y + 100));
            
        })
        .then((pointer) {

            // No change now
            assert(input.index == 0);
            assert(input.value == 1);

        })
        .runWhileDrawing(root);

    assert(input.value == 1);

}

@("Slider reacts to input actions")
unittest {

    auto input = slider!string(["One", "Two", "Three"]);
    assert(input.index == 0);
    assert(input.value == "One");

    input.runInputAction!(FluidInputAction.scrollRight);
    assert(input.index == 1);
    assert(input.value == "Two");

}
