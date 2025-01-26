module nodes.password_input;

import fluid;

@safe:

Theme testTheme;

static this() {
    testTheme = nullTheme.derive(
        rule!PasswordInput(
            Rule.fontSize = 14.pt,
            Rule.backgroundColor = color("#f0f"),
            Rule.selectionBackgroundColor = color("#700"),
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

@("PasswordInput draws a rectangle behind selection")
unittest {

    auto input = passwordInput(.testTheme);
    auto root = testSpace(input);

    input.value = "correct horse";
    root.draw();
    input.selectSlice("correct ".length, input.value.length);

    root.drawAndAssert(
        input.drawsRectangle(0, 0, 200, 27).ofColor("#ff00ff"),
        input.cropsTo       (0, 0, 200, 27),
        input.drawsRectangle(96, 0, 60, 27).ofColor("#770000"),
        input.drawsCircle().at(  5, 13.5).ofRadius(5).ofColor("#000000"),
        input.drawsCircle().at( 17, 13.5).ofRadius(5).ofColor("#000000"),
        // ... irrelevant dots skipped...
        input.drawsCircle().at( 89, 13.5).ofRadius(5).ofColor("#000000"),  // space
        input.drawsCircle().at(101, 13.5).ofRadius(5).ofColor("#000000"),  // h
        input.drawsCircle().at(113, 13.5).ofRadius(5).ofColor("#000000"),  // o
        input.drawsCircle().at(125, 13.5).ofRadius(5).ofColor("#000000"),  // r
        input.drawsCircle().at(137, 13.5).ofRadius(5).ofColor("#000000"),  // s
        input.drawsCircle().at(149, 13.5).ofRadius(5).ofColor("#000000"),  // e
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

@("PasswordInput correctly handles large inputs in HiDPI")
unittest {

    enum textConstant = " one two three four";

    auto node = passwordInput();
    auto focus = focusChain(node);
    auto root = testSpace(.testTheme, focus);
    root.setScale(1.25);
    focus.currentFocus = node;

    node.push(textConstant);
    root.draw();
    root.drawAndAssert(
        node.cropsTo(0, 0, 200, 27),
        node.drawsCircle().at(-7.84, 13.2).ofRadius(5.2).ofColor("#000000"),
        node.drawsCircle().at(4.64, 13.2).ofRadius(5.2).ofColor("#000000"),
        node.drawsCircle().at(17.12, 13.2).ofRadius(5.2).ofColor("#000000"),
        // ... more circles...
        node.drawsCircle().at(179.36, 13.2).ofRadius(5.2).ofColor("#000000"),
        node.drawsCircle().at(191.84, 13.2).ofRadius(5.2).ofColor("#000000"),
        node.drawsLine().from(199.12, 2.64).to(199.12, 23.76).ofWidth(1).ofColor("#000000"),
    );

    node.push(textConstant);
    root.drawAndAssert(
        node.cropsTo(0, 0, 200, 27),
        node.drawsCircle().at(-6.96003, 13.2).ofRadius(5.2).ofColor("#000000"),
        node.drawsCircle().at(5.51997, 13.2).ofRadius(5.2).ofColor("#000000"),
        node.drawsCircle().at(18, 13.2).ofRadius(5.2).ofColor("#000000"),
        // ... more circles...
        node.drawsCircle().at(180.24, 13.2).ofRadius(5.2).ofColor("#000000"),
        node.drawsCircle().at(192.72, 13.2).ofRadius(5.2).ofColor("#000000"),
        node.drawsLine().from(200, 2.64).to(200, 23.76).ofWidth(1).ofColor("#000000"),
    );

}

@("PasswordInput draws a placeholder when empty")
unittest {

    auto node = passwordInput("Placeholder...");
    auto root = testSpace(.testTheme, node);

    root.drawAndAssert(
        node.contentLabel.drawsHintedImage().at(0, 0, 121, 27).ofColor("#ffffff")
            .sha256("b842ed720b325d744e4efb138bc2609667cb6f0b8735375e9ab3f5cde72789c6"),
    );
    root.drawAndAssertFailure(
        node.drawsCircle(),
    );

    node.value = "a";

    root.drawAndAssertFailure(
        node.contentLabel.drawsHintedImage().at(0, 0, 121, 27).ofColor("#ffffff")
            .sha256("b842ed720b325d744e4efb138bc2609667cb6f0b8735375e9ab3f5cde72789c6"),
    );
    root.drawAndAssert(
        node.drawsCircle(),
    );

}
