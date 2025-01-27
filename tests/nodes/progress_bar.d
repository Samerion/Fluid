module nodes.progress_bar;

import fluid;

@safe:

Theme testTheme;

static this() {

    import fluid.theme;

    testTheme = nullTheme.derive(
        rule!ProgressBar(
            backgroundColor = color("#eee"),
            textColor = color("#000"),
        ),
        rule!ProgressBarFill(
            backgroundColor = color("#17b117"),
        )
    );

}

@("ProgressBar displays values using ProgressBarFill")
unittest {

    const steps = 24;

    auto bar = progressBar(steps);
    auto root = sizeLock!testSpace(
        .sizeLimit(800, 600),
        .testTheme,
        bar
    );

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

@("ProgressBar displays correctly in HiDPI")
unittest {

    const steps = 24;

    auto node = progressBar(steps);
    auto root = sizeLock!testSpace(
        .sizeLimit(400, 200),
        .testTheme,
        node
    );

    root.drawAndAssert(
        node.isDrawn().at(0, 0, 400, 27),
        node.drawsRectangle(0, 0, 400, 27).ofColor("#eeeeee"),
        node.fill.isDrawn().at(0, 0, 400, 27),
        node.fill.drawsRectangle(0, 0, 0, 27).ofColor("#17b117"),
        node.drawsHintedImage().at(187, 0, 26, 27).ofColor("#ffffff")
            .sha256("66dd88a8c076bdbc2cf58ab9a2c855e6c155aeae2428494537b2bf45c97e541d"),
    );

    root.setScale(1.25);
    root.drawAndAssert(
        node.isDrawn().at(0, 0, 400, 27),
        node.drawsRectangle(0, 0, 400, 27).ofColor("#eeeeee"),
        node.fill.isDrawn().at(0, 0, 400, 27),
        node.fill.drawsRectangle(0, 0, 0, 27).ofColor("#17b117"),
        node.drawsHintedImage().at(187.2, 0.3, 25.6, 26.4).ofColor("#ffffff")
            .sha256("0d527db3ea41c4f1b4b17d4f6b4bf6d1921f640e25b530b949baa78232fa0681"),
    );

}
