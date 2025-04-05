module nodes.slider;

import std.range;

import fluid;

@safe:

@("Slider draws a rail and a handle")
unittest {

    auto input = slider!int(
        .layout!"fill",
        iota(1, 4)
    );
    auto root = sizeLock!testSpace(
        .sizeLimit(500, 200),
        nullTheme.derive(
            rule!AbstractSlider(
                Rule.backgroundColor = color("#000"),
                Rule.lineColor = color("#f00"),
            ),
            rule!SliderHandle(
                Rule.backgroundColor = color("#0f0"),
            ),
        ),
        input,
    );

    root.drawAndAssert(

        // Rail
        input.drawsRectangle(0, 8, 500, 4).ofColor("#000"),

        // Marks
        input.drawsLine().from(  8, 12).to(  8, 20).ofWidth(1).ofColor("#f00"),
        input.drawsLine().from(250, 12).to(250, 20).ofWidth(1).ofColor("#f00"),
        input.drawsLine().from(492, 12).to(492, 20).ofWidth(1).ofColor("#f00"),

        // Handle
        input.handle.drawsRectangle(0, 0, 16, 20).ofColor("#0f0"),

    );

}

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

@("Pressing a slider with keyboard has no effect")
unittest {

    auto input = slider!string(["One", "Two", "Three"]);
    auto focus = focusChain();
    auto root = chain(hoverChain(), focus, input);
    root.draw();
    input.increment();
    assert(input.value == "Two");

    input.actionImpl(focus, 0, inputActionID!(FluidInputAction.press), true);
    assert(input.value == "Two");

}

@("Slider can have a default value assigned")
unittest {

    auto input1 = slider!int([0, 1, 2, 4, 8, 16], 3);
    assert(input1.index == 3);
    assert(input1.value == 4);
    auto input2 = slider!int([0, 1, 2, 4, 8, 16], 4);
    assert(input2.index == 4);
    assert(input2.value == 8);

}
