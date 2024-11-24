///
module fluid.progress_bar;

import fluid.text;
import fluid.node;
import fluid.backend;

@safe:

/// Progress bar node for communicating the program is actively working on something, and needs time to process. The
/// progress bar draws a styleable `ProgressBarFill` node inside, spanning a fraction of its content, usually starting
/// from left. Text is drawn over the node to display current progress.
///
/// The progress bar will use text height for its own height, but it needs extra horizontal space to be functional. To
/// make sure it displays, ensure its horizontal alignment is always set to "fill" — this is the default, if the layout
/// is not changed.
///
/// ## Styling
///
/// The `progressBar` component is split into two nodes, `ProgressBar` and `ProgressBarFill`. When styling, the
/// former defines the background, greyed out part of the node, and the latter defines the foreground, the fill
/// that appears as progress is accumulated. Usually, the background for `ProgressBar` will have low saturation or
/// be grayed out, and `ProgressBarFill` will be colorful.
///
/// Text currently uses the `ProgressBar` color, but it's possible it will blend the colors of both sides in the
/// future.
///
/// ---
/// Theme(
///     rule!ProgressBar(
///         backgroundColor = color("#eee"),
///         textColor = color("#000"),
///     ),
///     rule!ProgressBarFill(
///         backgroundColor = color("#17b117"),
///     )
/// )
/// ---
///
/// ## Text format
///
/// `ProgressBar` does not currently offer the possibility to change text format, but it can be accomplished by
/// subclassing and overriding the `buildText` method, like so:
///
/// ---
/// class MyProgressBar : ProgressBar {
///
///     override string buildText() const {
///
///         return format!"%s/%s"(value, maxValue);
///
///     }
///
/// }
/// ---
///
/// Importantly, should `buildText` return an empty string, the progress bar will disappear, since its size depends on
/// the text itself. If text is not desired, one can set `textColor` to a transparent value like `color("#0000")`.
/// Alternatively `resizeImpl` can also be overrided to change the sizing behavior.
alias progressBar = simpleConstructor!ProgressBar;

/// ditto
class ProgressBar : Node {

    public {

        /// `value`, along with `maxValue` indicate the current progress, defined as the fraction of `value` over
        /// `maxValue`. If 0, the progress bar is empty. If equal to `maxValue`, the progress bar is full.
        int value;

        /// ditto.
        int maxValue;

        /// Text used by the node.
        Text text;

        /// Node used as the filling for this progress bar.
        ProgressBarFill fill;

    }

    /// Set the `value` and `maxValue` of the progressBar.
    ///
    /// If initialized with no arguments, the progress bar starts empty, with `maxValue` set to 100.
    ///
    /// Params:
    ///     value = Current value. Defaults to 0, making the progress bar empty.
    ///     maxValue = Maximum value for the progress bar.
    this(int value, int maxValue) {

        this.layout = .layout!("fill", "start");
        this.value = value;
        this.maxValue = maxValue;
        this.fill = new ProgressBarFill(this);
        this.text = Text(this, "");

    }

    /// ditto
    this(int maxValue = 100) {

        this(0, maxValue);

    }

    override void resizeImpl(Vector2 space) {

        text = buildText();
        text.resize();
        fill.resize(tree, theme, space);
        minSize = text.size;

    }

    override void drawImpl(Rectangle paddingBox, Rectangle contentBox) {

        auto style = pickStyle();
        style.drawBackground(io, paddingBox);

        // Draw the filling
        fill.draw(contentBox);

        // Draw the text
        const textPosition = center(contentBox) - text.size / 2;
        text.draw(style, textPosition);

    }

    /// Get text that displays on top of the progress bar.
    ///
    /// This function can be overrided to adjust the text and its formatting, or to remove the text completely. Keep in
    /// mind that since `ProgressBar` uses the text as reference for its own size, if the text is removed, the progress
    /// bar will disappear — `minSize` has to be adjusted accordingly.
    string buildText() const {

        import std.format : format;

        const int percentage = 100 * value / maxValue;

        return format!"%s%%"(percentage);

    }

}

///
unittest {

    const steps = 24;

    // Create a progress bar.
    auto bar = progressBar(steps);

    // Keep the user updated on the progress.
    foreach (i; 0 .. steps) {

        bar.value = i;
        bar.updateSize();

    }

}

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

unittest {

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

/// Content for the progress bar. Used for styling. See `ProgressBar` for usage instructions.
class ProgressBarFill : Node {

    public {

        /// Progress bar the node belongs to.
        ProgressBar bar;

    }

    this(ProgressBar bar) {

        this.layout = .layout!"fill";
        this.bar = bar;

    }

    override void resizeImpl(Vector2 space) {

        minSize = Vector2(0, 0);

    }

    override void drawImpl(Rectangle paddingBox, Rectangle contentBox) {

        // Use a fraction of the padding box corresponding to the fill value
        paddingBox.width *= cast(float) bar.value / bar.maxValue;

        auto style = pickStyle();
        style.drawBackground(io, paddingBox);

    }

}
