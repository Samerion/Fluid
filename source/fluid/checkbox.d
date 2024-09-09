///
module fluid.checkbox;

import fluid.node;
import fluid.input;
import fluid.utils;
import fluid.style;
import fluid.backend;

@safe:

/// A checkbox can be selected by the user to indicate a true or false state.
alias checkbox = simpleConstructor!Checkbox;

/// ditto
class Checkbox : InputNode!Node {

    mixin enableInputActions;

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

        return _isChecked = value;

    }

    protected override void resizeImpl(Vector2 space) {

        minSize = size;

    }

    protected override void drawImpl(Rectangle outer, Rectangle inner) {

        import std.algorithm : min;

        auto style = pickStyle();

        style.drawBackground(io, outer);

        if (auto texture = getTexture(style)) {

            // Get the scale
            const scale = min(
                inner.width / texture.width,
                inner.height / texture.height
            );
            const size     = Vector2(texture.width * scale, texture.height * scale);
            const position = center(inner) - size/2;

            texture.draw(Rectangle(position.tupleof, size.tupleof));

        }

    }

    /// Get checkmark texture used by this checkbox.
    protected TextureGC* getTexture(Style style) @trusted {

        auto extra = cast(Extra) style.extra;

        // No valid extra data, ignore
        if (!extra) return null;

        // Load the texture
        return extra.getTexture(io, extra.checkmark);

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

unittest {

    int changed;

    auto io = new HeadlessBackend;
    auto root = checkbox(delegate {

        changed++;

    });

    root.io = io;
    root.runInputAction!(FluidInputAction.press);

    assert(changed == 1);
    assert(root.isChecked);

    root.runInputAction!(FluidInputAction.press);

    assert(changed == 2);
    assert(!root.isChecked);

}
