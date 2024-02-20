///
module fluid.radiobox;

import fluid.node;
import fluid.input;
import fluid.utils;
import fluid.style;
import fluid.backend;
import fluid.checkbox;

@safe:

/// A radiobox is similar to checkbox, except only one in a group can be selected at a time.
///
/// Styles: $(UL
///   $(LI `styleKey` = Default style for the button.)
///   $(LI `checkedStyleKey` = Style the radiobox uses when checked.)
///   $(LI `hoverStyleKey` = Style to apply when the button is hovered.)
///   $(LI `focusStyleKey` = Style to apply when the button is focused.)
/// )
alias radiobox = simpleConstructor!Radiobox;

/// ditto
class Radiobox : Checkbox {

    mixin defineStyles;
    mixin enableInputActions;

    static class Extra : Checkbox.Extra {

        /// Width of the radiobox outline.
        int outlineWidth;

        /// Color of the outline.
        Color outlineColor;

        /// Fill color for the checkbox.
        Color fillColor;

        this(int outlineWidth, Color outlineColor, Color fillColor) {

            super(Image.init);
            this.outlineWidth = outlineWidth;
            this.outlineColor = outlineColor;
            this.fillColor = fillColor;

        }

    }

    public {

        /// Group this radiobox belongs to. In a single group, only one radiobox can be selected.
        RadioboxGroup group;
        invariant(group);

    }

    /// Create a new radiobox.
    /// Params:
    ///     params = Layout/theme for the radiobox.
    ///     group = Group the radiobox belongs to.
    ///     isChecked = Whether the radiobox should be checked or not.
    this(NodeParams params, RadioboxGroup group, bool isChecked = false) {

        this.group = group;
        super(params);

        // Select if ordered to do so.
        if (isChecked) group.selection = this;

    }

    override bool isChecked() const {

        return this is group.selection;

    }

    override bool isChecked(bool value) {

        // Select this checkbox if set to true
        if (value) select();

        // If set to false, and if checked, nullify selection
        else if (isChecked) {

            group.selection = null;

        }

        return value;

    }

    /// Check this radiobox.
    void select() {

        group.selection = this;

    }

    @(FluidInputAction.press)
    override protected void _pressed() {

        // Do nothing if already checked
        if (isChecked) return;

        // Check the box
        select();
        if (changed) changed();

    }

    protected override void drawImpl(Rectangle outer, Rectangle inner) {

        import std.algorithm : min;

        // TODO set rounded borders instead of drawing a circle?

        auto style = pickStyle();

        super.drawImpl(outer, inner);

        if (auto extra = cast(Extra) style.extra) {

            const outerRadius = min(
                outer.width / 2,
                outer.height / 2,
            );
            const innerRadius = min(
                inner.width / 2,
                inner.height / 2,
            );

            // Draw the outline
            io.drawCircleOutline(center(outer), outerRadius, extra.outlineColor);

            // Draw the inside
            if (isChecked)
            io.drawCircle(center(inner), innerRadius, extra.fillColor);

        }

    }

}

class RadioboxGroup {

    /// Selected item.
    Radiobox selection;

}
