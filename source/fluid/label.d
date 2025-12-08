/// Node for displaying text.
///
/// A label takes a [string] or a [Rope], and displays it on the screen when drawn.
/// Labels can be constructed using the [label][label] node builder.
module fluid.label;

@safe:

///
@("Label example")
unittest {

    // Label takes just a single argument: the text to display
    auto myLabel = label("Hello, World!");

    // You can access and change label text
    myLabel.text ~= " It's a nice day today!";

    // Text will automatically wrap if it's too long to fit, but you can toggle it off
    myLabel.isWrapDisabled = true;

}

import fluid.node;
import fluid.text;
import fluid.utils;
import fluid.style;

import fluid.io.canvas;

/// A [node builder][nodeBuilder] that constructs a label.
alias label = nodeBuilder!Label;

/// A node that displays text on the screen.
///
/// Label inherits only from [Node].
class Label : Node {

    CanvasIO canvasIO;

    public {

        /// Text of this label. For most purposes acts like a [Rope] or [string], see [Text] for
        /// more details.
        Text text;

        alias value = text;

        /// If true, all of the text of this label will display in one line.
        /// Otherwise, and by default, the text will *wrap* to fit within available space.
        bool isWrapDisabled;

    }

    /// Construct the label.
    /// Params:
    ///     text = Initial label text; either a [Rope] or a [string].
    this(Rope text) {
        this.text = Text(this, text);
    }

    /// ditto
    this(const(char)[] text) {
        this.text = Text(this, text);
    }

    /// Set wrap on or off for this node.
    /// See_Also:
    ///     [isWrapDisabled], the field controlled by these methods
    This disableWrap(this This = Label)() return {
        isWrapDisabled = true;
        return cast(This) this;
    }

    /// ditto
    This enableWrap(this This = Label)() return {
        isWrapDisabled = false;
        return cast(This) this;
    }

    /// Returns:
    ///     True if the label is empty; it has no text.
    bool isEmpty() const {
        return text.length == 0;
    }

    protected override void resizeImpl(Vector2 available) {
        import std.math;

        use(canvasIO);

        text.resize(canvasIO, available, !isWrapDisabled);
        minSize = text.size;

        assert(text.isMeasured);
    }

    protected override void drawImpl(Rectangle outer, Rectangle inner) {
        const style = pickStyle();
        style.drawBackground(canvasIO, outer);
        text.draw(canvasIO, style, inner.start);
    }

    override string toString() const {
        import std.range;
        import std.format;

        return format!"Label(%(%s%))"(only(text.toString));
    }

}
