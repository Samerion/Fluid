module nodes.frame;

import fluid;

@safe:

@("Frame draws background and border")
unittest {

    import fluid.theme;
    import fluid.test_space;

    @NodeTag
    enum WithBorder;

    auto theme = nullTheme.derive(
        rule!(Frame)(
            backgroundColor = color("#f00"),
        ),
        rule!(Frame, WithBorder)(
            border = 1,
            borderStyle = colorBorder(color("#0f0")),
        ),
    );

    auto plainFrame = vframe();
    auto frameWithBorder = vframe(.tags!WithBorder);
    auto test = testSpace(
        theme,
        plainFrame,
        frameWithBorder,
    );

    test.drawAndAssert(
        // No border on plainFrame
        plainFrame.drawsRectangle().ofColor("#f00"),
        plainFrame.doesNotDraw(),
        // frameWithBorders draws background and border
        frameWithBorder.drawsRectangle().ofColor("#f00"),
        frameWithBorder.drawsRectangle().ofColor("#0f0"),
        frameWithBorder.drawsRectangle().ofColor("#0f0"),
        frameWithBorder.drawsRectangle().ofColor("#0f0"),
        frameWithBorder.drawsRectangle().ofColor("#0f0"),
    );

}
