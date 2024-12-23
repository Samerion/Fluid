module nodes.progress_bar;

import fluid;

@safe:

@("ProgressBar displays values using ProgressBarFill")
unittest {

    import fluid.theme;

    const steps = 24;

    auto theme = nullTheme.derive(
        rule!ProgressBar(
            backgroundColor = color("#eee"),
            textColor = color("#000"),
        ),
        rule!ProgressBarFill(
            backgroundColor = color("#17b117"),
        )
    );
    auto bar = progressBar(steps);
    auto root = testSpace(.layout!"fill", theme, bar);

    root.draw();
    assert(bar.text == "0%");

    root.drawAndAssert(
        bar.drawsRectangle(0, 0, 800, 27).ofColor("#eee"),
        bar.fill.drawsRectangle(0, 0, 0, 27).ofColor("#17b117"),
        bar.drawsImage(bar.text.texture.chunks[0].image).at(387, 0),
    );

    bar.value = 2;
    bar.updateSize();
    root.draw();

    assert(bar.text == "8%");
    root.drawAndAssert(
        bar.drawsRectangle(0, 0, 800, 27).ofColor("#eee"),
        bar.fill.drawsRectangle(0, 0, 66.66, 27).ofColor("#17b117"),
        bar.drawsImage(bar.text.texture.chunks[0].image).at(387.5, 0),
    );

    bar.value = steps;
    bar.updateSize();
    root.draw();

    assert(bar.text == "100%");
    root.drawAndAssert(
        bar.drawsRectangle(0, 0, 800, 27).ofColor("#eee"),
        bar.fill.drawsRectangle(0, 0, 800, 27).ofColor("#17b117"),
        bar.drawsImage(bar.text.texture.chunks[0].image).at(377, 0),
    );

}

@("Progress bar text can be changed by overriding buildText")
unittest {

    import fluid.theme;

    auto theme = nullTheme.derive(
        rule!ProgressBar(
            backgroundColor = color("#eee"),
        ),
        rule!ProgressBarFill(
            backgroundColor = color("#17b117"),
        )
    );
    auto bar = new class ProgressBar {

        override void resizeImpl(Vector2 space) {

            super.resizeImpl(space);
            minSize = Vector2(0, 4);

        }

        override string buildText() const {

            return "";

        }

    };
    bar.maxValue = 20;
    auto root = testSpace(.layout!"fill", theme, bar);

    root.drawAndAssert(
        bar.drawsRectangle(0, 0, 800, 4).ofColor("#eee"),
        bar.fill.drawsRectangle(0, 0, 0, 4).ofColor("#17b117"),
    );
    assert(bar.text == "");

    bar.value = 2;
    bar.updateSize();
    bar.draw();

    root.drawAndAssert(
        bar.drawsRectangle(0, 0, 800, 4).ofColor("#eee"),
        bar.fill.drawsRectangle(0, 0, 80, 4).ofColor("#17b117"),
    );
    assert(bar.text == "");

}
