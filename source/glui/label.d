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

    mixin DefineStyles;
    mixin ImplHoveredRect;

    public {

        /// Text of this label.
        string text;

        /// If true, the content of the label should not be wrapped into new lines if it's too long to fit into one.
        bool disableWrap;

    }

    static foreach (index; 0 .. BasicNodeParamLength) {

        /// Initialize the label with given text.
        this(BasicNodeParam!index sup, string text = "") {

            super(sup);
            this.text = text;

        }

    }

    protected override void resizeImpl(Vector2 available) {

        minSize = style.measureText(available, text, !disableWrap);

    }

    protected override void drawImpl(Rectangle outer, Rectangle inner) {

        const style = pickStyle();
        style.drawBackground(outer);
        style.drawText(inner, text, !disableWrap);

    }

    protected override const(Style) pickStyle() const {

        return style;

    }

}
