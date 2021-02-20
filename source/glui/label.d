module glui.label;

import raylib;

import glui.node;
import glui.utils;

alias label = simpleConstructor!GluiLabel;

/// A label can be used to display text on the screen.
class GluiLabel : GluiNode {

    /// Text of this label.
    string text;

    /// Initialize the label with given text.
    this(T...)(T sup, string text) {

        super(sup);
        this.text = text;

    }

    protected override void resize(Vector2 available) {

        minSize = style.measureText(available, text);

    }

    protected override void drawImpl(Rectangle area) const {

        style.drawBackground(area);
        style.drawText(area, text);

    }

}
