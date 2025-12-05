module nodes.checkbox;

import fluid;

@safe:

Theme testTheme;

static this() {
    import fluid.theme;
    testTheme = Theme(
        rule!Checkbox(
            margin = 0,
            border = 1,
            padding = 0,
            borderStyle = colorBorder(color("#222")),
        ),
    );
}

@("Pressing the checkbox toggles its state")
unittest {

    int changed;

    auto root = checkbox(delegate {
        changed++;
    });

    root.runInputAction!(FluidInputAction.press);

    assert(changed == 1);
    assert(root.isChecked);

    root.runInputAction!(FluidInputAction.press);

    assert(changed == 2);
    assert(!root.isChecked);

}

@("Checkbox draws a checkmark when pressed")
unittest {

    auto input = checkbox();
    auto test = testSpace(.testTheme, input);
    input.size = Vector2(10, 10);

    test.drawAndAssert(
        input.drawsRectangle().ofColor("#222"),
        input.drawsRectangle().ofColor("#222"),
        input.drawsRectangle().ofColor("#222"),
        input.drawsRectangle().ofColor("#222"),
        input.drawsImage(Image.init),
    );
    assert(input.markImage == Image.init);

    input.toggle();
    test.draw(),
    test.drawAndAssert(
        input.drawsRectangle().ofColor("#222"),
        input.drawsImage(input.markImage),
    );
    assert(input.markImage != Image.init);

}

@("Checkboxes are unaffected by HiDPI")
unittest {

    auto input = checkbox(true);
    auto root = testSpace(.testTheme, input);
    input.size = Vector2(10, 10);

    root.drawAndAssert(
        input.drawsImage().at(1, 2.09375, 10, 7.8125).ofColor("#ffffff")
            .sha256("ac69b943d56d2f5a077127ca3b30f7388d2be42d4f22c4b26eba479585cad291")
    );
    root.setScale(1.25);
    root.drawAndAssert(
        input.drawsImage().at(1, 2.09375, 10, 7.8125).ofColor("#ffffff")
            .sha256("ac69b943d56d2f5a077127ca3b30f7388d2be42d4f22c4b26eba479585cad291")
    );


}
