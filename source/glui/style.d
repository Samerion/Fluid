///
module glui.style;

import raylib;
import std.string;

/// Node theme.
alias Theme = Style[immutable(StyleKey)*];

/// An empty struct used to create unique style type identifiers.
struct StyleKey { }

/// Create a new style initialized with given D code.
///
/// raylib and std.string are accessible inside by default.
Style style(string init)() {

    auto result = new Style;
    result.update!init;

    return result;

}

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

        /// If true, text will be wrapped. Requires align=fill on height.
        bool textWrap = true;
        // TODO for other aligns

    }

    // Background
    struct {

        /// Background color of the node.
        Color backgroundColor;

    }

    this() {

        font = GetFontDefault;

    }

    /// Get the default, empty style.
    static Style init() {

        static Style val;
        if (val is null) val = new Style;
        return val;

    }

    ///
    private void update(string code)() {

        mixin(code);

    }

    /// Measure space given text will use.
    /// Params:
    ///     availableSpace = Space available for drawing.
    ///     text           = Text to draw.
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

/// Define styles.
/// params:
///     Names = A list of styles to define.
mixin template DefineStyles(names...) {

    static foreach(i, name; names) {

        // Only check even names
        static if (i % 2 == 0) {

            // Define the key
            mixin("static immutable StyleKey " ~ name ~ "Key;");

            // Define the value
            mixin("@StyleKey private Style " ~ name ~ ";");

        }

    }

    override protected void reloadStyles() {

        super.reloadStyles();

        static foreach (i, name; names) {

            static if (i % 2 == 0) {

                mixin(name) = cast() theme.get(&mixin(name ~ "Key"), mixin(names[i+1]));

            }

        }

    }

}
