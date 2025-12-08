/// A [ProgressBar] node is commonly used to communicate the program is actively working on
/// something, and needs time to process. It updates the user on the status by indicating the
/// fraction of work that has been completed.
///
/// The progress bar draws a styleable [ProgressBarFill] node inside, spanning some of its
/// content, usually starting from left. Current progress is also displayed on top of the progress
/// bar as text.
///
/// <!-- -->
module fluid.progress_bar;

@safe:

/// Create new progress bars with [progressBar].
@("ProgressBar reference example")
unittest {
    run(
        progressBar(1, 5),  // 1/5 of the job is done
    );
}

/// The progress bar will copy text height for its own height, but it needs extra horizontal space
/// to be functional. To make sure it displays, ensure its horizontal alignment is always set to
/// "fill" — this is the default, if the layout is not changed.
///
/// Current progress is stored in the [value][ProgressBar.value] field. Update it regularly and
/// call [updateSize][Node.updateSize] afterwards.
@("ProgressBar reference example #2")
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
/// ## Styling
///
/// The `progressBar` component is split into two nodes, [ProgressBar] and [ProgressBarFill].
/// When styling, the former defines the background, greyed out part of the node, and the latter
/// defines the foreground, the fill that appears as progress is made. Usually, the background
/// for `ProgressBar` will have low saturation or be grayed out, and `ProgressBarFill` will be
/// colorful.
///
/// Text currently uses the `ProgressBar` color, but it's possible it will blend the colors of
/// both sides in the future.
///
unittest {
    import fluid.theme;
    Theme(
        rule!ProgressBar(
            backgroundColor = color("#eee"),
            textColor = color("#000"),
        ),
        rule!ProgressBarFill(
            backgroundColor = color("#17b117"),
        )
    );
}

/// ## Text format
///
/// `ProgressBar` can't currently change text formatting on its own, but text can be changed by
/// subclassing and overriding the [buildText][ProgressBar.buildText] method.
///
/// Importantly, should `buildText` return an empty string, the progress bar will disappear, since
/// its size depends on the text itself. If text is not desired, one can set `textColor` to a
/// transparent value like `color("#0000")`. Alternatively [resizeImpl][Node.resizeImpl] can also
/// be overridden to change the sizing behavior.
@("ProgressBar text format example")
unittest {
    class MyProgressBar : ProgressBar {

        override string buildText() const {
            import std.format;
            return format!"%s/%s"(value, maxValue);
        }

    }
}

import fluid.text;
import fluid.node;
import fluid.utils;
import fluid.structs;

import fluid.io.canvas;

/// A [node builder][nodeBuilder] that constructs a [ProgressBar].
alias progressBar = nodeBuilder!ProgressBar;

/// A progress bar is a node that fills up to indicate the program has made progress in a
/// time-taking action, such as loading or copying files.
class ProgressBar : Node {

    CanvasIO canvasIO;

    public {

        /// `value`, along with `maxValue` indicate the current progress, defined as the fraction
        /// of `value` over `maxValue`. If `0`, the progress bar is empty. If equal to `maxValue`,
        /// the progress bar is full.
        int value;

        /// ditto
        int maxValue;

        /// Text displayed by the node. It cannot be updated externally; the progress bar will
        /// change the text on update.
        Text text;

        /// Node used as the filling for this progress bar. As progress is added, `fill` takes up
        /// more of `ProgressBar`'s space.
        ProgressBarFill fill;

    }

    /// Set the `value` and `maxValue` of the progress bar.
    ///
    /// If initialized with one or zero arguments, the progress bar starts empty. The only
    /// argument, if given, sets the target progress (`maxValue`).
    ///
    /// Two values can be passed to specify a fraction.
    ///
    /// Params:
    ///     value    = Current value. Defaults to `0`, making the progress bar empty.
    ///     maxValue = Maximum value for the progress bar. Defaults to `100`.
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

        use(canvasIO);

        text = buildText();
        text.resize(canvasIO);
        resizeChild(fill, space);
        minSize = text.size;

    }

    override void drawImpl(Rectangle paddingBox, Rectangle contentBox) {

        auto style = pickStyle();
        style.drawBackground(io, canvasIO, paddingBox);

        // Draw the filling
        drawChild(fill, contentBox);

        // Draw the text
        const textPosition = center(contentBox) - text.size / 2;

        text.draw(canvasIO, style, textPosition);

    }

    /// Get text that displays on top of the progress bar.
    ///
    /// This function can be overridden to adjust the text, or to remove the text completely. Keep
    /// in mind that since `ProgressBar` uses the text as reference for its own size, if the text
    /// is removed, the progress bar will disappear — `minSize` has to be adjusted accordingly.
    ///
    /// Returns:
    ///     Text for the progress bar to use.
    string buildText() const {

        import std.format : format;

        const int percentage = 100 * value / maxValue;

        return format!"%s%%"(percentage);

    }

}


/// Content for the progress bar. Used for styling. See [ProgressBar] for usage instructions.
class ProgressBarFill : Node {

    CanvasIO canvasIO;

    public {

        /// Progress bar the node belongs to.
        ProgressBar bar;

    }

    /// Construct fill using data from the given progress bar.
    ///
    /// For the fill to apply, it has to be then assigned to [ProgressBar.fill]; that is not
    /// done automatically.
    ///
    /// Params:
    ///     bar = Bar to take progress data from.
    this(ProgressBar bar) {
        this.layout = .layout!"fill";
        this.bar = bar;
    }

    override void resizeImpl(Vector2 space) {
        use(canvasIO);
        minSize = Vector2(0, 0);
    }

    override void drawImpl(Rectangle paddingBox, Rectangle contentBox) {

        // Use a fraction of the padding box corresponding to the fill value
        paddingBox.width *= cast(float) bar.value / bar.maxValue;

        auto style = pickStyle();
        style.drawBackground(io, canvasIO, paddingBox);

    }

}
