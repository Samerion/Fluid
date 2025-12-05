module tests.styles.tint;

import fluid;

@safe:

@("Style.tint stacks")
unittest {

    auto myTheme = nullTheme.derive(
        rule!Frame(
            Rule.backgroundColor = color!"fff",
            Rule.tint = color!"aaaa",
        ),
    );

    Frame[4] frames;
    auto root = testSpace(
        frames[0] = sizeLock!vframe(
            .sizeLimit(800, 600),
            .layout!(1, "fill"),
            myTheme,
            frames[1] = vframe(
                layout!(1, "fill"),
                frames[2] = vframe(
                    layout!(1, "fill"),
                    frames[3] = vframe(
                        layout!(1, "fill"),
                    )
                ),
            ),
        ),
    );

    auto rect = Rectangle(0, 0, 800, 600);
    auto bg = color!"fff";

    // Background rectangles — all covering the same area, but with fading color and transparency
    root.drawAndAssert(
        frames[0].drawsRectangle(rect).ofColor(bg = multiply(bg, color!"aaaa")),
        frames[1].drawsRectangle(rect).ofColor(bg = multiply(bg, color!"aaaa")),
        frames[2].drawsRectangle(rect).ofColor(bg = multiply(bg, color!"aaaa")),
        frames[3].drawsRectangle(rect).ofColor(bg = multiply(bg, color!"aaaa")),
    );

}

