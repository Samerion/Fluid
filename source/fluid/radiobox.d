///
module fluid.radiobox;

import fluid.node;
import fluid.input;
import fluid.utils;
import fluid.style;
import fluid.checkbox;

@safe:

/// A radiobox is similar to checkbox, except only one in a group can be selected at a time.
alias radiobox = nodeBuilder!Radiobox;

/// ditto
class Radiobox : Checkbox {

    mixin enableInputActions;

    static class Extra : Checkbox.Extra {

        /// Width of the radiobox outline.
        int outlineWidth;

        /// Color of the outline.
        auto outlineColor = Color(0, 0, 0, 0);

        /// Fill color for the checkbox.
        auto fillColor = Color(0, 0, 0, 0);

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
    ///     group = Group the radiobox belongs to.
    ///     isChecked = Whether the radiobox should be checked or not.
    this(RadioboxGroup group, bool isChecked = false) {

        this.group = group;

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

        // Do nothing if already checked
        if (isChecked) return;

        // Check the box
        group.selection = this;
        if (changed) changed();

    }

    /// ditto
    @(FluidInputAction.press)
    override void press() {

        select();

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

            // Draw the inside
            canvasIO.drawCircle(center(inner), innerRadius, extra.fillColor);

            // Draw the outline
            canvasIO.drawCircleOutline(center(outer), outerRadius, extra.outlineWidth, extra.outlineColor);

        }

    }

}

///
unittest {

    // Radioboxes are similar to checkboxes, except that only one in a group
    // can be checked at a time
    auto group = new RadioboxGroup;
    auto box1 = radiobox(group);
    auto box2 = radiobox(group);

    box1.select();

    assert(box1.isChecked);

    // Checking the other box will uncheck the previous one
    box2.select();

    assert(!box1.isChecked);
    assert(box2.isChecked);

}

class RadioboxGroup {

    /// Selected item.
    Radiobox selection;

}
