module tests.styles.children;

import fluid;
import fluid.theme;

@safe:

unittest {

    auto outerColor = color("#444");
    auto innerColor = color("#222");

    auto theme = nullTheme.derive(
        rule!Frame(
            children!Button(
                margin = 6,
                backgroundColor = innerColor,
            ),
        ),
        rule!Button(
            margin = 2,
            backgroundColor = outerColor,
        ),
    );

    Button outer, inner;

    auto root = testSpace(
        theme,
        outer = button("", delegate { }),
        vframe(
            inner = button("", delegate { }),
        ),
    );

    root.drawAndAssert(
        outer.drawsRectangle(2,  2, 0, 0),
        inner.drawsRectangle(6, 10, 0, 0),
    );

}
