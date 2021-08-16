///
module glui.style;

import raylib;

import std.math;
import std.range;
import std.string;
import std.typecons;
import std.algorithm;

import glui.utils;

public import glui.style_macros;

@safe:

/// Node theme.
alias StyleKeyPtr = immutable(StyleKey)*;
alias Theme = Style[StyleKeyPtr];

/// An empty struct used to create unique style type identifiers.
struct StyleKey { }

/// Create a new style initialized with given D code.
///
/// raylib and std.string are accessible inside by default.
///
/// Params:
///     init = D code to use.
///     data = Data to pass to the code as the context. All fields of the struct will be within the style's scope.
Style style(string init, Data)(Data data) {

    auto result = new Style;

    with (data) with (result) mixin(init);

    return result;

}

/// Ditto.
Style style(string init)() {

    auto result = new Style;
    result.update!init;

    return result;

}

/// Contains a style for a node.
class Style {

    enum Side {

        left, right, top, bottom,

    }

    // Internal use only, can't be private because it's used in mixins.
    static {

        Theme _currentTheme;
        Style[] _styleStack;

    }

    // Text options
    struct {

        /// Font to be used for the text.
        Font font;

        /// Font size (height) in pixels.
        float fontSize = 24;

        /// Line height, as a fraction of `fontSize`.
        float lineHeight = 1.4;

        /// Space between characters, relative to font size.
        float charSpacing = 0.1;

        /// Space between words, relative to the font size.
        float wordSpacing = 0.5;

        /// Text color.
        Color textColor = Colors.BLACK;

    }

    // Background
    struct {

        /// Background color of the node.
        Color backgroundColor;

    }

    // Spacing
    struct {

        /// Margin (outer margin) of the node. `[left, right, top, bottom]`.
        ///
        /// Tip: You can directly set all margins with eg. `margin = 6;`
        ///
        /// See: enum `Side`
        uint[4] margin;

        /// Padding (inner margin) of the node. `[left, right, top, bottom]`.
        ///
        /// See: enum `Side`
        uint[4] padding;

    }

    // Misc
    struct {

        /// Cursor icon to use while this node is hovered.
        ///
        /// Custom image cursors are not supported yet.
        MouseCursor mouseCursor;

    }

    this() { }

    /// Create a style by copying params of others.
    ///
    /// Multiple styles can be set, so if one field is set to `typeof(field).init`, it will be taken from the previous
    /// style from the list — that is, settings from the last style override previous ones.
    this(Style[] styles...) {

        import std.meta, std.traits;

        // Check each style
        foreach (i, style; styles) {

            // Inherit each field
            static foreach (field; FieldNameTuple!(typeof(this))) {{

                auto inheritedField = mixin("style." ~ field);

                // Ignore if it's set to init (unless it's the first style)
                if (i == 0 || inheritedField != typeof(inheritedField).init) {

                    mixin("this." ~ field) = inheritedField;

                }

            }}

        }

    }

    /// Get the default, empty style.
    static Style init() {

        static Style val;
        if (val is null) val = new Style;
        return val;

    }

    /// Update the style with given D code.
    ///
    /// This allows each init code to have a consistent default scope, featuring `glui`, `raylib` and chosen `std`
    /// modules.
    ///
    /// Params:
    ///     init = Code to update the style with.
    ///     T    = An compile-time object to update the scope with.
    void update(string init)() {

        import glui;

        // Wrap init content in brackets to allow imports
        // See: https://forum.dlang.org/thread/nl4vse$egk$1@digitalmars.com
        // The thread mentions mixin templates but it's the same for string mixins too; and a mixin with multiple
        // statements is annoyingly treated as multiple separate mixins.
        mixin(init.format!"{ %s }");

    }

    /// Ditto.
    void update(string init, T)() {

        import glui;

        with (T) mixin(init.format!"{ %s }");

    }

    /// Get the current font
    inout(Font) getFont() inout @trusted {

        return cast(inout) (font.recs ? font : GetFontDefault);

    }

    /// Measure space given text will use.
    ///
    /// Params:
    ///     availableSpace = Space available for drawing.
    ///     text           = Text to draw.
    ///     wrap           = If true (default), the text will be wrapped to match available space, unless the space is
    ///                      empty.
    /// Returns:
    ///     If `availableSpace` is a vector, returns the result as a vector.
    ///
    ///     If `availableSpace` is a rectangle, returns a rectangle of the size of the result, offset to the position
    ///     of the given rectangle.
    Vector2 measureText(Vector2 availableSpace, string text, bool wrap = true) const {

        auto wrapped = wrapText(availableSpace.x, text, !wrap || availableSpace.x == 0);

        return Vector2(
            wrapped.map!"a.width".maxElement,
            wrapped.length * fontSize * lineHeight,
        );

    }

    /// Ditto
    Rectangle measureText(Rectangle availableSpace, string text, bool wrap = true) const {

        const vec = measureText(
            Vector2(availableSpace.width, availableSpace.height),
            text, wrap
        );

        return Rectangle(
            availableSpace.x, availableSpace.y,
            vec.x, vec.y
        );

    }

    /// Draw text using the same params as `measureText`.
    void drawText(Rectangle rect, string text, bool wrap = true) const {

        // Text position from top, relative to given rect
        size_t top;

        const totalLineHeight = fontSize * lineHeight;

        // Draw each line
        foreach (line; wrapText(rect.width, text, !wrap)) {

            scope (success) top += cast(size_t) ceil(lineHeight * fontSize);

            // Stop if drawing below rect
            if (top > rect.height) break;

            // Text position from left
            size_t left;

            const margin = (totalLineHeight - fontSize)/2;

            foreach (word; line.words) {

                const position = Vector2(rect.x + left, rect.y + top + margin);

                () @trusted {

                    // cast(): raylib doesn't mutate the font. The parameter would probably be defined `const`, but
                    // since it's not transistive in C, and font is a struct with a pointer inside, it only matters
                    // in D.

                    DrawTextEx(cast() getFont, word.text.toStringz, position, fontSize, fontSize * charSpacing,
                        textColor);

                }();

                left += cast(size_t) ceil(word.width + fontSize * wordSpacing);

            }

        }

    }

    /// Split the text into multiple lines in order to fit within given width.
    ///
    /// Params:
    ///     width         = Container width the text should fit in.
    ///     text          = Text to wrap.
    ///     lineFeedsOnly = If true, this should only wrap the text on line feeds.
    TextLine[] wrapText(double width, string text, bool lineFeedsOnly) const {

        const spaceSize = cast(size_t) ceil(fontSize * wordSpacing);

        auto result = [TextLine()];

        /// Get width of the given word.
        float wordWidth(string wordText) @trusted {

            // See drawText for cast()
            return MeasureTextEx(cast() getFont, wordText.toStringz, fontSize, fontSize * charSpacing).x;

        }

        TextLine.Word[] words;

        auto whitespaceSplit = text[]
            .splitter!((a, string b) => [' ', '\n'].canFind(a), Yes.keepSeparators)(" ");

        // Pass 1: split on words, calculate minimum size
        foreach (chunk; whitespaceSplit.chunks(2)) {

            const wordText = chunk.front;
            const size = cast(size_t) wordWidth(wordText).ceil;

            chunk.popFront;
            const feed = chunk.empty
                ? false
                : chunk.front == "\n";

            // Push the word
            words ~= TextLine.Word(wordText, size, feed);

            // Update minimum size
            if (size > width) width = size;

        }

        // Pass 2: calculate total size
        foreach (word; words) {

            scope (success) {

                // Start a new line if this words is followed by a line feed
                if (word.lineFeed) result ~= TextLine();

            }

            auto lastLine = &result[$-1];

            // If last line is empty
            if (lastLine.words == []) {

                // Append to it immediately
                lastLine.words ~= word;
                lastLine.width += word.width;
                continue;

            }


            // Check if this word can fit
            if (lineFeedsOnly || lastLine.width + spaceSize + word.width <= width) {

                // Push it to this line
                lastLine.words ~= word;
                lastLine.width += spaceSize + word.width;

            }

            // It can't
            else {

                // Push it to a new line
                result ~= TextLine([word], word.width);

            }

        }

        return result;

    }

    /// Draw the background
    void drawBackground(Rectangle rect) const @trusted {

        DrawRectangleRec(rect, backgroundColor);

    }

    /// Remove padding from the vector representing size of a box.
    Vector2 contentBox(Vector2 size) const {

        size.x = max(0, size.x - padding[0] - padding[1]);
        size.y = max(0, size.y - padding[2] - padding[3]);

        return size;

    }

    /// Remove padding from the given rect.
    Rectangle contentBox(Rectangle rect) const {

        rect.x += padding[0];
        rect.y += padding[2];

        const size = contentBox(Vector2(rect.w, rect.h));
        rect.width = size.x;
        rect.height = size.y;

        return rect;

    }

}

/// `wrapText` result.
struct TextLine {

    struct Word {

        string text;
        size_t width;
        bool lineFeed;  // Word is followed by a line feed.

    }

    /// Words on this line.
    Word[] words;

    /// Width of the line (including spaces).
    size_t width = 0;

}

ref uint sideLeft(return ref uint[4] sides) {

    return sides[Style.Side.left];

}
ref uint sideRight(return ref uint[4] sides) {

    return sides[Style.Side.right];

}
ref uint sideTop(return ref uint[4] sides) {

    return sides[Style.Side.top];

}

ref uint sideBottom(return ref uint[4] sides) {

    return sides[Style.Side.bottom];

}

ref uint[2] sideX(return ref uint[4] sides) {

    const start = Style.Side.left;
    return sides[start .. start + 2];

}

ref uint[2] sideY(return ref uint[4] sides) {

    const start = Style.Side.top;
    return sides[start .. start + 2];

}
