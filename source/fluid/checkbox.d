///
module fluid.checkbox;

import fluid.node;
import fluid.input;
import fluid.utils;
import fluid.style;
import fluid.backend;

@safe:

/// A checkbox can be selected by the user to indicate a true or false state.
///
/// Styles: $(UL
///   $(LI `styleKey` = Default style for the button.)
///   $(LI `checkedStyleKey` = Style the checkbox uses when checked.)
///   $(LI `hoverStyleKey` = Style to apply when the button is hovered.)
///   $(LI `focusStyleKey` = Style to apply when the button is focused.)
/// )
alias checkbox = simpleConstructor!Checkbox;

/// ditto
class Checkbox : InputNode!Node {

    mixin defineStyles!(
        "checkedStyle", q{ hoverStyle },
    );
    mixin implHoveredRect;
    mixin enableInputActions;

    /// Additional features available for checkbox styling.
    static class Extra : StyleExtension {

        /// Image to use for the checkmark.
        Image checkmark;

        /// Checkmark texture cache, by image pointer.
        static private TextureGC[Color*][FluidBackend] cache;

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
    ///     params = Layout/theme for the checkbox.
    ///     isChecked = Whether the checkbox should be checked or not.
    this(NodeParams params, bool isChecked = false) {

        super(params);
        this._isChecked = isChecked;
        this.size = Vector2(10, 10);

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
        if (extra.checkmark.area == 0) return null;

        // Check entries for this backend
        auto entries = extra.cache.require(backend, new TextureGC[Color*]);
        auto index = extra.checkmark.pixels.ptr;

        // Check entries for this image
        if (auto texture = index in entries) {

            return texture;

        }

        // No entry, create one
        else {

            entries[index] = TextureGC(io, extra.checkmark);
            return index in entries;

        }

    }


    /// Toggle the checkbox.
    void toggle() {

        isChecked = !isChecked;

    }

    @(FluidInputAction.press)
    protected void _pressed() {

        toggle();
        if (changed) changed();

    }

    /// Pick the style.
    protected override inout(Style) pickStyle() inout {

        // If checked
        if (isChecked) return checkedStyle;

        // If focused
        if (isFocused) return focusStyle;

        // If hovered
        if (isHovered) return hoverStyle;

        // No decision — normal state
        return super.pickStyle();

    }

    static if (is(typeof(text) : string))
    override string toString() const {

        if (isChecked)
            return "checkbox(true)";
        else
            return "checkbox()";

    }

}
