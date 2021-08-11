///
module glui.label;

import raylib;

import glui.node;
import glui.utils;
import glui.style;

alias label = simpleConstructor!GluiLabel;

@safe:

/// A label can be used to display text on the screen.
/// Styles: $(UL
///     $(LI `style` = Default style for this node.)
/// )
class GluiLabel : GluiNode {

    mixin ImplHoveredRect;

    /// Text of this label.
    string text;

    static foreach (index; 0 .. BasicNodeParamLength) {

        /// Initialize the label with given text.
        this(BasicNodeParam!index sup, string text = "") {

            super(sup);
            this.text = text;

        }

    }

    protected override void resizeImpl(Vector2 available) {

        minSize = style.measureText(available, text);

    }

    protected override void drawImpl(Rectangle area) {

        const style = pickStyle();
        style.drawBackground(area);
        style.drawText(area, text);

    }

    protected override const(Style) pickStyle() const {

        return style;

    }

}
