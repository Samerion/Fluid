module nodes.checkbox;

import fluid;

@safe:

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

    auto theme = Theme(
        rule!Checkbox(
            Rule.margin = 0,
            Rule.border = 1,
            Rule.padding = 0,
            Rule.borderStyle = colorBorder(color("#222")),
        ),
    );
    auto input = checkbox();
    auto test = testSpace(theme, input);
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
