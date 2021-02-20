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
    void drawText(Rectangle rect, string text) const {

        import std.string : toStringz;

        DrawTextRec(cast() font, text.toStringz, rect, fontSize, 1f, textWrap, textColor);
        // Note: I doubt DrawTextRec has any side-effects on font.
        // Most likely it isn't const because the keyword isn't transistive in C, so it wouldn't affect the parameter,
        // while it does in D.

    }

    /// Draw the background
    void drawBackground(Rectangle rect) const {

        DrawRectangleRec(rect, backgroundColor);

    }

}
