module glui.style;

import raylib;

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

    // Layout
    struct {

        /// Margin of the node.
        uint[2] margin;

        /// Padding (inner margin) of the node.
        uint[2] padding;

    }

    this() {

        font = GetFontDefault;

    }

    /// Draw text using the params
    void drawText(Rectangle rect, string text) {

        import std.string : toStringz;

        DrawTextRec(font, text.toStringz, rect, fontSize, 1f, textWrap, textColor);

    }

    /// Draw the background
    void drawBackground(Rectangle rect) {

        DrawRectangleRec(rect, backgroundColor);

    }

}
