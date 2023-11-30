///
module glui.label;

import raylib;

import glui.node;
import glui.text;
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
        Text!GluiLabel text;

        /// If true, the content of the label should not be wrapped into new lines if it's too long to fit into one.
        bool disableWrap;

    }

    static foreach (index; 0 .. BasicNodeParamLength) {

        /// Initialize the label with given text.
        this(BasicNodeParam!index sup, string text) {

            super(sup);
            this.text = Text!GluiLabel(this, text);

        }

        /// Initialize the label with given text.
        deprecated("text argument for labels is now required. This overload is to be removed in 0.7.0")
        this(BasicNodeParam!index sup) {

            super(sup);
            this.text = Text!GluiLabel(this, text);

        }

    }

    protected override void resizeImpl(Vector2 available) {

        import std.math;

        text.resize(available, !disableWrap);
        minSize = text.size;

    }

    protected override void drawImpl(Rectangle outer, Rectangle inner) {

        const style = pickStyle();
        style.drawBackground(outer);
        text.draw(style, inner);

    }

    override const(Style) pickStyle() const {

        return style;

    }

}
