module glui.label;

import raylib;
import std.string;

import glui.node;

/// A label can be used to display text on the screen.
class GluiLabel : GluiNode {

    /// Text of this label.
    string text;

    this(T...)(T sup, string text) {

        super(sup);
        this.text = text;

    }

    protected override void resize(Vector2 available) {

        minSize = MeasureTextEx(style.font, text.toStringz, style.fontSize, 1.0);

    }

    protected override void drawImpl(Rectangle area) {

        style.drawBackground(area);
        style.drawText(area, text);

    }

}
