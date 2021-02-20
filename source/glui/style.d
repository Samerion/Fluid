module glui.style;

import raylib;
import std.string;

/// Contains a style for a node.
class Style {

    // Text options
    struct {

        /// Font to be used for the text.
        Font font;

        /// Font size (height) in pixels.
        float fontSize = 24;

        /// Text color.
        Color textColor = Colors.BLACK;

        /// If true, text will be wrapped.
        bool textWrap;

    }

    // Background
    struct {

        /// Background color of the node.
        Color backgroundColor;

    }

    this() {

        font = GetFontDefault;

    }

    /// Measure given text will use.
    /// Params:
    ///     availableSpace = Space available for drawing.
    Vector2 measureText(Vector2 availableSpace, string text) const {

        return MeasureTextEx(cast() font, text.toStringz, fontSize, fontSize / 10f);

    }

    /// Draw text using the params
    void drawText(Rectangle rect, string text) const {

        DrawTextRec(cast() font, text.toStringz, rect, fontSize, fontSize / 10f, textWrap, textColor);
        // Note: I doubt DrawTextRec has any side-effects on the font.
        // Most likely it isn't const because the keyword isn't transistive in C, so it wouldn't affect the parameter.
        // It does in D, because the struct contains pointers.

    }

    /// Draw the background
    void drawBackground(Rectangle rect) const {

        DrawRectangleRec(rect, backgroundColor);

    }

}
