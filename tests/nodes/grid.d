module nodes.grid;

import fluid;

@safe:

@("GridFrame and GridRow draw background")
unittest {

    GridRow firstRow, secondRow;

    auto grid = sizeLock!gridFrame(
        .sizeLimit(500, 500),
        .segments(3),
        .nullTheme.derive(
            rule!GridFrame(
                Rule.backgroundColor = color("#f00"),
            ),
            rule!GridRow(
                Rule.backgroundColor = color("#0f0"),
            ),
        ),

        firstRow = sizeLock!gridRow(
            .sizeLimitY(100),
            label(.layout!1, "One"),
            label(.layout!1, "Two"),
            label(.layout!1, "Three"),
        ),
        secondRow = sizeLock!gridRow(
            .sizeLimitY(100),
            label(.layout!1, "One"),
            label(.layout!1, "Two"),
            label(.layout!1, "Three"),
        ),
    );
    auto root = testSpace(grid);

    root.drawAndAssert(
        grid     .drawsRectangle(0,   0, 500, 500).ofColor("#ff0000"),
        firstRow .drawsRectangle(0,   0, 500, 100).ofColor("#00ff00"),
        secondRow.drawsRectangle(0, 100, 500, 100).ofColor("#00ff00"),
    );

}
