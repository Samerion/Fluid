@Migrated
module legacy.progress_bar;

import fluid;
import legacy;

@safe:

@("ProgressBar displays values using ProgressBarFill")
@Migrated
unittest {

    import fluid.theme;

    const steps = 24;

    auto io = new HeadlessBackend;
    auto theme = nullTheme.derive(
        rule!ProgressBar(
            backgroundColor = color("#eee"),
            textColor = color("#000"),
        ),
        rule!ProgressBarFill(
            backgroundColor = color("#17b117"),
        )
    );
    auto bar = progressBar(theme, steps);

    bar.io = io;
    bar.draw();

    assert(bar.text == "0%");
    io.assertRectangle(Rectangle(0, 0, 800, 27), color("#eee"));
    io.assertRectangle(Rectangle(0, 0, 0, 27), color("#17b117"));
    io.assertTexture(bar.text.texture.chunks[0].texture, Vector2(387, 0), color("#fff"));

    io.nextFrame;
    bar.value = 2;
    bar.updateSize();
    bar.draw();

    assert(bar.text == "8%");
    io.assertRectangle(Rectangle(0, 0, 800, 27), color("#eee"));
    io.assertRectangle(Rectangle(0, 0, 66.66, 27), color("#17b117"));
    io.assertTexture(bar.text.texture.chunks[0].texture, Vector2(387.5, 0), color("#fff"));

    io.nextFrame;
    bar.value = steps;
    bar.updateSize();
    bar.draw();

    assert(bar.text == "100%");
    io.assertRectangle(Rectangle(0, 0, 800, 27), color("#eee"));
    io.assertRectangle(Rectangle(0, 0, 800, 27), color("#17b117"));
    io.assertTexture(bar.text.texture.chunks[0].texture, Vector2(377, 0), color("#fff"));

}

@("Progress bar text can be changed by overriding buildText")
@Migrated
unittest {

    import fluid.style;
    import fluid.theme;

    auto io = new HeadlessBackend;
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

    bar.io = io;
    bar.theme = theme;
    bar.maxValue = 20;
    bar.draw();

    assert(bar.text == "");
    io.assertRectangle(Rectangle(0, 0, 800, 4), color("#eee"));
    io.assertRectangle(Rectangle(0, 0, 0, 4), color("#17b117"));

    io.nextFrame;
    bar.value = 2;
    bar.updateSize();
    bar.draw();

    assert(bar.text == "");
    io.assertRectangle(Rectangle(0, 0, 800, 4), color("#eee"));
    io.assertRectangle(Rectangle(0, 0, 80, 4), color("#17b117"));

}

