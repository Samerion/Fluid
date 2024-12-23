module nodes.separator;

import fluid;

@safe:

@("separator draws a vertical or horizontal line")
unittest {

    import fluid.theme;

    auto theme = nullTheme.derive(
        rule!Separator(
            lineColor = color("#000"),
        ),
    );

    auto separator = nodeSlot!Separator(
        .layout!(1, "fill"),
    );
    auto root = sizeLock!testSpace(
        .sizeLimit(100, 100),
        theme,
        separator
    );

    // Vertical
    separator = vseparator();
    root.drawAndAssert(
        separator.value.draws(),
    );
    root.drawAndAssert(
        separator.value.drawsLine().from(50, 0).to(50, 100).ofWidth(1).ofColor("#000"),
    );

    // Horizontal
    separator = hseparator();
    root.drawAndAssert(
        separator.value.drawsLine().from(0, 50).to(100, 50).ofWidth(1).ofColor("#000"),
    );

}
