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

    deprecated("Use this(NodeParams, string text) instead.") {

        static foreach (index; 0 .. BasicNodeParamLength) {

            /// Initialize the label with given text.
            this(BasicNodeParam!index sup, string text = "") {

                super(sup);
                this.text = Text!GluiLabel(this, text);

            }

        }

    }

    this(NodeParams params, string text) {

        super(params);
        this.text = Text!GluiLabel(this, text);

    }

    deprecated("`text` is now a required parameter for label — please adjust before 0.7.0.")
    this(NodeParams params) {

        super(params);
        this.text = Text!GluiLabel(this, text);

    }

    protected override void resizeImpl(Vector2 available) {

        import std.math;

        text.resize(available, !disableWrap);
        minSize = text.size;

    }

    protected override void drawImpl(Rectangle outer, Rectangle inner) {

        const style = pickStyle();
        style.drawBackground(tree.io, outer);
        text.draw(style, inner);

    }

    override const(Style) pickStyle() const {

        return style;

    }

}
