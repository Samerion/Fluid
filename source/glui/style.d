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

        /// Space between characters, relative to font size.
        float charSpacing = 0.1;

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

        auto res = MeasureTextEx(cast() font, text.toStringz, fontSize, fontSize * charSpacing);
        return Vector2(res.x + fontSize * charSpacing * 2, res.y);

    }

    /// Measure the box of the text.
    /// Params:
    ///     availableSpace = Space available for drawing.
    ///     text           = Text to draw.
    Rectangle measureText(Rectangle availableSpace, string text) const {

        const vec = measureText(
            Vector2(availableSpace.width, availableSpace.height),
            text,
        );

        return Rectangle(
            availableSpace.x, availableSpace.y,
            vec.x, vec.y
        );

    }

    /// Draw text using the params
    void drawText(Rectangle rect, string text) const {

        DrawTextRec(cast() font, text.toStringz, rect, fontSize, fontSize * charSpacing, textWrap, textColor);
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
///     names = A list of styles to define.
mixin template DefineStyles(names...) {

    import std.traits : BaseClassesTuple;
    import std.meta : Filter;

    import glui.utils : StaticFieldNames;

    private alias Parent = BaseClassesTuple!(typeof(this))[0];
    private alias MemberType(alias member) = typeof(__traits(getMember, Parent, member));

    private enum isStyleKey(alias member) = is(MemberType!member == immutable(StyleKey));
    private alias StyleKeys = Filter!(isStyleKey, StaticFieldNames!Parent);

    // Inherit style keys
    static foreach (field; StyleKeys) {

        mixin("static immutable StyleKey " ~ field ~ ";");

    }

    // Local styles
    static foreach(i, name; names) {

        // Only check even names
        static if (i % 2 == 0) {

            // Define the key
            mixin("static immutable StyleKey " ~ name ~ "Key;");

            // Define the value
            mixin("protected Style " ~ name ~ ";");

        }

    }

    // Load styles
    override protected void reloadStyles() {

        import std.stdio;
        import std.traits;

        super.reloadStyles();

        static foreach (name; StyleKeys) {{

            if (auto style = &mixin(name) in theme) {

                mixin("this." ~ name[0 .. $-3]) = cast() *style;

            }

        }}

        static foreach (i, name; names) {

            static if (i % 2 == 0) {

                mixin(name) = cast() theme.get(&mixin(name ~ "Key"), mixin(names[i+1]));

            }

        }

    }

}
