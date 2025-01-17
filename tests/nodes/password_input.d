module nodes.password_input;

import fluid;

@safe:

Theme testTheme;

static this() {
    testTheme = nullTheme.derive(
        rule!PasswordInput(
            Rule.fontSize = 14.pt,
            Rule.backgroundColor = color("#f0f"),
            Rule.textColor = color("#000"),
        ),
    );
}

@("PasswordInput draws background and contents")
unittest {

    auto input = passwordInput(.testTheme);
    auto root = testSpace(input);

    root.drawAndAssert(
        input.drawsRectangle(0, 0, 200, 27).ofColor("#ff00ff"),
        input.cropsTo(0, 0, 200, 27),
        input.resetsCrop(),
    );
    input.value = "woo";
    root.drawAndAssert(
        input.drawsRectangle(0, 0, 200, 27).ofColor("#ff00ff"),
        input.cropsTo(0, 0, 200, 27),
        input.drawsCircle().at( 5, 13.5).ofRadius(5).ofColor("#000000"),
        input.drawsCircle().at(17, 13.5).ofRadius(5).ofColor("#000000"),
        input.drawsCircle().at(29, 13.5).ofRadius(5).ofColor("#000000"),
        input.resetsCrop(),
    );

}

@("PasswordInput scrolls when there is too much text to fit in its width")
unittest {

    auto input = passwordInput(.testTheme);
    auto root = testSpace(input);

    input.value = "correct horse battery staple";
    root.draw();
    input.caretToEnd();

    root.drawAndAssert(
        input.drawsRectangle(0, 0, 200, 27).ofColor("#ff00ff"),
        input.cropsTo       (0, 0, 200, 27),
        // ... many irrelevant dots skipped...
        input.drawsCircle().at(-23, 13.5).ofRadius(5).ofColor("#000000"),
        input.drawsCircle().at(-11, 13.5).ofRadius(5).ofColor("#000000"),
        input.drawsCircle().at(  1, 13.5).ofRadius(5).ofColor("#000000"),
        input.drawsCircle().at( 13, 13.5).ofRadius(5).ofColor("#000000"),
        // ... more dots skipped...
        input.drawsCircle().at(181, 13.5).ofRadius(5).ofColor("#000000"),
        input.drawsCircle().at(193, 13.5).ofRadius(5).ofColor("#000000"),
        input.resetsCrop(),
    );

}

@("PasswordInput.shred fills data with invalid characters")
unittest {

    auto root = passwordInput();
    root.value = "Hello, ";
    root.caretToEnd();
    root.push("World!");

    assert(root.value == "Hello, World!");

    auto value1 = root.value;
    root.shred();

    assert(root.value == "");
    assert(value1 == "Hello, \xFF\xFF\xFF\xFF\xFF\xFF");

    root.push("Hello, World!");
    root.runInputAction!(FluidInputAction.previousChar);

    auto value2 = root.value;
    root.chopWord();
    root.push("Fluid");

    auto value3 = root.value;

    assert(root.value == "Hello, Fluid!");
    assert(value2 == "Hello, World!");
    assert(value3 == "Hello, Fluid!");

    root.shred();

    assert(root.value == "");
    assert(value2 == "\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF");
    assert(value3 == value2);

}

@("PasswordInput.shred clears edit history")
unittest {

    auto root = passwordInput();
    root.push("Hello, x");
    root.chop();
    root.push("World!");

    assert(root.value == "Hello, World!");

    root.undo();

    assert(root.value == "Hello, ");

    root.shred();

    assert(root.value == "");

    root.undo();

    assert(root.value == "");

    root.redo();
    root.redo();

    assert(root.value == "");

}
