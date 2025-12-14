///
module fluid.checkbox;

import fluid.node;
import fluid.input;
import fluid.utils;
import fluid.style;
import fluid.image_view;

import fluid.io.canvas;

@safe:

/// A checkbox can be selected by the user to indicate a true or false state.
alias checkbox = simpleConstructor!Checkbox;

/// ditto
class Checkbox : InputNode!Node {

    mixin enableInputActions;

    CanvasIO canvasIO;

    /// Additional features available for checkbox styling.
    static class Extra : typeof(super).Extra {

        /// Image to use for the checkmark.
        Image checkmark;

        this(Image checkmark) {
            this.checkmark = checkmark;
        }

    }

    // Button status
    public {

        /// Size of the checkbox.
        Vector2 size;

    }

    private {

        DrawableImage _markImage;
        bool _isChecked;

    }

    /// Create a new checkbox.
    /// Params:
    ///     isChecked = Whether the checkbox should be checked or not.
    ///     changed   = Callback to run whenever the user changes the value.
    this(bool isChecked, void delegate() @safe changed = null) {

        this(changed);
        this._isChecked = isChecked;

    }

    /// ditto
    this(void delegate() @safe changed = null) {

        this.size = Vector2(10, 10);
        this.changed = changed;

    }

    /// If true, the box is checked.
    bool isChecked() const {
        return _isChecked;

    }

    /// ditto
    bool isChecked(bool value) {
        updateSize();
        return _isChecked = value;
    }

    /// Get the currently used checkmark image. Requires `CanvasIO`, updated on resize.
    /// Returns:
    ///     Active checkmark image.
    inout(Image) markImage() inout {
        return _markImage;
    }

    protected override void resizeImpl(Vector2 space) {

        use(canvasIO);

        if (canvasIO) {
            _markImage = getImage(pickStyle());
            load(canvasIO, _markImage);
        }

        minSize = size;

    }

    protected override void drawImpl(Rectangle outer, Rectangle inner) {
        import std.algorithm : min;

        auto style = pickStyle();
        style.drawBackground(canvasIO, outer);

        const size = _markImage.size.fitInto(inner.size);
        const position = center(inner) - size/2;
        _markImage.draw(
            Rectangle(position.tupleof, size.tupleof));
    }

    /// Get checkmark image used by this checkbox.
    protected Image getImage(Style style) {

        if (auto extra = cast(Extra) style.extra) {
            return extra.checkmark;
        }
        return Image.init;

    }

    /// Toggle the checkbox.
    void toggle() {

        isChecked = !isChecked;
        if (changed) changed();

    }

    /// ditto
    @(FluidInputAction.press)
    protected void press() {

        toggle();

    }

    static if (is(typeof(text) : string))
    override string toString() const {

        if (isChecked)
            return "checkbox(true)";
        else
            return "checkbox()";

    }

}

///
unittest {

    // Checkbox creates a toggleable button
    auto myCheckbox = checkbox();

    assert(!myCheckbox.isChecked);

}
