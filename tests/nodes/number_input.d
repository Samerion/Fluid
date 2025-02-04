module nodes.number_input;

import fluid;

import std.algorithm;

@safe:

@("NumberInput supports scientific notation")
unittest {

    import std.math;

    auto input = floatInput();
    auto focus = focusChain();
    auto root = chain(focus, input);

    focus.typeText("10e8");
    focus.currentFocus = input;
    root.draw();

    focus.runInputAction!(FluidInputAction.submit);
    root.draw();

    assert(input.value.isClose(10e8));
    assert(input.value.isClose(1e9));
    assert(input.TextInput.value.among("1e+9", "1e+09"));

}

@("NumberInput supports math operations")
unittest {

    int calls;

    auto input = intInput(delegate {
        calls++;
    });
    auto focus = focusChain();
    auto root = chain(focus, input);

    // First frame: initial state
    focus.currentFocus = input;
    root.draw();
    assert(input.value == 0);
    assert(input.TextInput.value == "0");

    // Second frame, type in "10"; value should remain unchanged
    focus.typeText("10");
    root.draw();
    assert(calls == 0);
    assert(input.value == 0);
    assert(input.TextInput.value.among("010", "10"));

    // Submit to update
    focus.runInputAction!(FluidInputAction.submit);
    root.draw();
    assert(calls == 1);
    assert(input.value == 10);
    assert(input.TextInput.value == "10");

    // Test math equations
    focus.typeText("+20*5");
    root.draw();
    assert(calls == 1);
    assert(input.value == 10);
    assert(input.TextInput.value == "10+20*5");

    // Submit the expression
    input.submit();
    root.draw();
    assert(calls == 2);
    assert(input.value != (10+20)*5);
    assert(input.value == 110);
    assert(input.TextInput.value == "110");

}

@("NumberInput supports incrementing and decrementing through buttons")
unittest {

    int calls;

    auto input = intInput(delegate { calls++; });
    auto hover = hoverChain();
    auto root = chain(hover, input);

    root.theme = Theme(
        rule!IntInput(
            Rule.margin  = 0,
            Rule.border  = 0,
            Rule.padding = 0,
        ),
        rule!NumberInputSpinner(
            Rule.margin  = 0,
            Rule.border  = 0,
            Rule.padding = 0,
        ),
    );

    input.TextInput.value = "10+1";
    root.draw();

    const size = input.getMinSize;
    const bottom = size - Vector2(1, 1);  // safety margin
    const top = Vector2(bottom.x, 0);

    // Try incrementing
    hover.point(top)
        .then((a) {
            assert(a.isHovered(input.spinner));
            a.press;
            return a.stayIdle;
        })
        .then((a) {
            assert(calls == 1);  // Does this make sense?
            assert(input.value == 12);
            assert(input.TextInput.value == "12");

            // Try decrementing
            return a.move(bottom - Vector2(1, 1));
        })
        .then((a) {
            a.press;
            assert(a.isHovered(input.spinner));
            return a.stayIdle;
        })
        .runWhileDrawing(root);

    assert(calls == 2);
    assert(input.value == 11);
    assert(input.TextInput.value == "11");

}

@("NumberInput correctly scales buttons in HiDPI")
unittest {

    auto input = intInput();
    auto root = testSpace(input);
    auto node = input.spinner;

    // 100% scale
    root.drawAndAssert(
        node.drawsRectangle(6, 2, 200, 27).ofColor("#00000000"),
        node.drawsImage().at(189.125, 2, 16.875, 27).ofColor("#ffffff")
            .sha256("341d0882a4db03e29bfa6b016d133c6082df3c2d6817978adc82d3678310565e"),
    );

    // 125% scale, buttons are drawn all the same
    root.setScale(1.25);
    root.drawAndAssert(
        node.drawsRectangle(6, 2, 200, 27).ofColor("#00000000"),
        node.drawsImage().at(189.125, 2, 16.875, 27).ofColor("#ffffff")
            .sha256("341d0882a4db03e29bfa6b016d133c6082df3c2d6817978adc82d3678310565e"),
    );

}

@("NumberInputSpinner correctly maps visual space in HiDPI")
unittest {

    int ups, downs;

    auto node = new NumberInputSpinner(
        { ups++; },
        { downs++; },
    );
    auto hover = hoverChain(node);
    auto root = sizeLock!testSpace(
        .sizeLimit(100, 100),
        hover,
    );

    node.layout = .layout!"fill";
    hover.layout = .layout!(1, "fill");

    // Scale does not affect hitboxes
    foreach (scale; [1.00, 1.25]) {
        ups = 0;
        downs = 0;

        root.setScale(scale);
        hover.point(99, 49)
            .then((a) {
                a.click();
                assert(ups   == 1);
                assert(downs == 0);
                return a.move(99, 51);
            })
            .then((a) {
                a.click();
                assert(ups   == 1);
                assert(downs == 1);
            })
            .runWhileDrawing(root);
    }

    assert(ups   == 1);
    assert(downs == 1);

}
