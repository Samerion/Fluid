///
module glui.style;

import raylib;

import std.math;
import std.range;
import std.string;
import std.typecons;
import std.algorithm;

import glui.node;
import glui.utils;

public import glui.border;
public import glui.style_macros;


@safe:


alias StyleKeyPtr = immutable(StyleKey)*;

/// Node theme.
alias Theme = Style[StyleKeyPtr];

/// Side array is a static array defining a property separately for each side of a box, for example margin and border
/// size. Order is as follows: `[left, right, top, bottom]`. You can use `Style.Side` to index this array with an enum.
///
/// Because of the default behavior of static arrays, one can set the value for all sides to be equal with a simple
/// assignment: `array = 8`. Additionally, to make it easier to manipulate the box, one may use the `sideX` and `sideY`
/// functions to get a `uint[2]` array of the values corresponding to the given axis (which can also be assigned like
/// `array.sideX = 8`) or the `sideLeft`, `sideRight`, `sideTop` and `sideBottom` functions corresponding to the given
/// sides.
enum isSideArray(T) = is(T == X[4], X);

///
unittest {

    uint[4] sides;
    static assert(isSideArray!uint);

    sides.sideX = 4;

    assert(sides.sideLeft == sides.sideRight);
    assert(sides.sideLeft == 4);

    sides = 8;
    assert(sides == [8, 8, 8, 8]);
    assert(sides.sideX == sides.sideY);

}

/// An empty struct used to create unique style type identifiers.
struct StyleKey { }

/// Create a new style initialized with given D code.
///
/// raylib and std.string are accessible inside by default.
///
/// Note: It is recommended to create a root style node defining font parameters and then inherit other styles from it.
///
/// Params:
///     init    = D code to use.
///     parents = Styles to inherit from. See `Style.this` documentation for more info.
///     data    = Data to pass to the code as the context. All fields of the struct will be within the style's scope.
Style style(string init, Data)(Data data, Style[] parents...) {

    auto result = new Style;

    with (data) with (result) mixin(init);

    return result;

}

/// Ditto.
Style style(string init)(Style[] parents...) {

    auto result = new Style(parents);
    result.update!init;

    return result;

}

/// Create a color from hex code.
Color color(string hexCode)() {

    return color(hexCode);

}

/// ditto
Color color(string hexCode) pure {

    import std.format;

    // Remove the # if there is any
    const hex = hexCode.chompPrefix("#");

    Color result;
    result.a = 0xff;

    switch (hex.length) {

        // 4 digit RGBA
        case 4:
            formattedRead!"%x"(hex[3..4], result.a);
            result.a *= 17;

            // Parse the rest like RGB
            goto case;

        // 3 digit RGB
        case 3:
            formattedRead!"%x"(hex[0..1], result.r);
            formattedRead!"%x"(hex[1..2], result.g);
            formattedRead!"%x"(hex[2..3], result.b);
            result.r *= 17;
            result.g *= 17;
            result.b *= 17;
            break;

        // 8 digit RGBA
        case 8:
            formattedRead!"%x"(hex[6..8], result.a);
            goto case;

        // 6 digit RGB
        case 6:
            formattedRead!"%x"(hex[0..2], result.r);
            formattedRead!"%x"(hex[2..4], result.g);
            formattedRead!"%x"(hex[4..6], result.b);
            break;

        default:
            assert(false, "Invalid hex code length");

    }

    return result;

}

unittest {

    import std.exception;

    assert(color!"#123" == Color(0x11, 0x22, 0x33, 0xff));
    assert(color!"#1234" == Color(0x11, 0x22, 0x33, 0x44));
    assert(color!"1234" == Color(0x11, 0x22, 0x33, 0x44));
    assert(color!"123456" == Color(0x12, 0x34, 0x56, 0xff));
    assert(color!"2a5592f0" == Color(0x2a, 0x55, 0x92, 0xf0));

    assertThrown(color!"ag5");

}

/// Contains the style for a node.
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
        float fontSize;

        /// Line height, as a fraction of `fontSize`.
        float lineHeight;

        /// Space between characters, relative to font size.
        float charSpacing;

        /// Space between words, relative to the font size.
        float wordSpacing;

        /// Text color.
        Color textColor;

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
        /// See: `isSideArray`.
        uint[4] margin;

        /// Border size, placed between margin and padding. `[left, right, top, bottom]`.
        ///
        /// See: `isSideArray`
        uint[4] border;

        /// Padding (inner margin) of the node. `[left, right, top, bottom]`.
        ///
        /// See: `isSideArray`
        uint[4] padding;

        /// Border style to use.
        GluiBorder borderStyle;

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

                static if (__traits(compiles, inheritedField is null)) {

                    const isInit = inheritedField is null;

                }
                else {

                    const isInit = inheritedField == inheritedField.init;

                }

                // Ignore if it's set to init (unless it's the first style)
                if (i == 0 || !isInit) {

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

    static Font loadFont(string file, int fontSize, dchar[] fontChars = null) @trusted {

        const realSize = fontSize * hidpiScale.y;

        return LoadFontEx(file.toStringz, cast(int) realSize.ceil, cast(int*) fontChars.ptr,
            cast(int) fontChars.length);

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
    Vector2 measureText(Vector2 availableSpace, string text, bool wrap = true) const
    in (availableSpace.x.isFinite && availableSpace.y.isFinite,
        format!"Text space given must be finite: %s"(availableSpace))
    in (fontSize.isFinite,
        format!"Invalid font size %s"(fontSize))
    in (lineHeight.isFinite,
        format!"Invalid line height %s"(lineHeight))
    out (r; r.x.isFinite && r.y.isFinite,
        format!"Resulting text space must be finite: %s"(r))
    do {

        auto wrappedLines = wrapText(availableSpace.x, text, !wrap || availableSpace.x == 0);


        return Vector2(
            wrappedLines.map!"a.width".maxElement,
            wrappedLines.length * fontSize * lineHeight,
        );

    }

    /// Ditto
    Rectangle measureText(Rectangle availableSpace, string text, bool wrap = true) const
    do {

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

    /// Get a side array holding both the regular margin and the border.
    uint[4] fullMargin() const {

        return [
            margin.sideLeft + border.sideLeft,
            margin.sideRight + border.sideRight,
            margin.sideTop + border.sideTop,
            margin.sideBottom + border.sideBottom,
        ];

    }

    /// Remove padding from the vector representing size of a box.
    Vector2 contentBox(Vector2 size) const {

        return cropBox(size, padding);

    }

    /// Remove padding from the given rect.
    Rectangle contentBox(Rectangle rect) const {

        return cropBox(rect, padding);

    }

    /// Get a sum of margin, border size and padding.
    uint[4] totalMargin() const {

        uint[4] ret = margin[] + border[] + padding[];
        return ret;

    }

    /// Crop the given box by reducing its size on all sides.
    static Vector2 cropBox(Vector2 size, uint[4] sides) {

        size.x = max(0, size.x - sides.sideLeft - sides.sideRight);
        size.y = max(0, size.y - sides.sideTop - sides.sideBottom);

        return size;

    }

    /// ditto
    static Rectangle cropBox(Rectangle rect, uint[4] sides) {

        rect.x += sides.sideLeft;
        rect.y += sides.sideTop;

        const size = cropBox(Vector2(rect.w, rect.h), sides);
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

/// Get a reference to the left, right, top or bottom side of the given side array.
ref inout(uint) sideLeft(T)(return ref inout T sides)
if (isSideArray!T) {

    return sides[Style.Side.left];

}

/// ditto
ref inout(uint) sideRight(T)(return ref inout T sides)
if (isSideArray!T) {

    return sides[Style.Side.right];

}

/// ditto
ref inout(uint) sideTop(T)(return ref inout T sides)
if (isSideArray!T) {

    return sides[Style.Side.top];

}

/// ditto
ref inout(uint) sideBottom(T)(return ref inout T sides)
if (isSideArray!T) {

    return sides[Style.Side.bottom];

}

///
unittest {

    uint[4] sides = [8, 0, 4, 2];

    assert(sides.sideRight == 0);

    sides.sideRight = 8;
    sides.sideBottom = 4;

    assert(sides == [8, 8, 4, 4]);

}

/// Get a reference to the X axis for the given side array.
ref inout(uint[2]) sideX(T)(return ref inout T sides)
if (isSideArray!T) {

    const start = Style.Side.left;
    return sides[start .. start + 2];

}

ref inout(uint[2]) sideY(T)(return ref inout T sides)
if (isSideArray!T) {

    const start = Style.Side.top;
    return sides[start .. start + 2];

}

///
unittest {

    uint[4] sides = [1, 2, 3, 4];

    assert(sides.sideX == [sides.sideLeft, sides.sideRight]);
    assert(sides.sideY == [sides.sideTop, sides.sideBottom]);

    sides.sideX = 8;

    assert(sides == [8, 8, 3, 4]);

    sides.sideY = sides.sideBottom;

    assert(sides == [8, 8, 4, 4]);

}

/// Returns a side array created from either: another side array like it, a two item array with each representing an
/// axis like `[x, y]`, or a single item array or the element type to fill all values with it.
T[4] normalizeSideArray(T, size_t n)(T[n] values) {

    // Already a valid side array
    static if (n == 4) return values;

    // Axis array
    else static if (n == 2) return [values[0], values[0], values[1], values[1]];

    // Single item array
    else static if (n == 1) return [values[0], values[0], values[0], values[0]];

    else static assert(false, format!"Unsupported static array size %s, expected 1, 2 or 4 elements."(n));


}

/// ditto
T[4] normalizeSideArray(T)(T value) {

    return [value, value, value, value];

}

/// Shift the side clockwise (if positive) or counter-clockwise (if negative).
Style.Side shiftSide(Style.Side side, int shift) {

    // Convert the side to an "angle" — 0 is the top, 1 is right and so on...
    const angle = side.predSwitch(
        Style.Side.top, 0,
        Style.Side.right, 1,
        Style.Side.bottom, 2,
        Style.Side.left, 3,
    );

    // Perform the shift
    const shifted = (angle + shift) % 4;

    // And convert it back
    return shifted.predSwitch(
        0, Style.Side.top,
        1, Style.Side.right,
        2, Style.Side.bottom,
        3, Style.Side.left,
    );

}

unittest {

    assert(shiftSide(Style.Side.left, 0) == Style.Side.left);
    assert(shiftSide(Style.Side.left, 1) == Style.Side.top);
    assert(shiftSide(Style.Side.left, 2) == Style.Side.right);
    assert(shiftSide(Style.Side.left, 4) == Style.Side.left);

    assert(shiftSide(Style.Side.top, 1) == Style.Side.right);

}

/// Make a style point the other way around
Style.Side reverse(Style.Side side) {

    with (Style.Side)
    return side.predSwitch(
        left, right,
        right, left,
        top, bottom,
        bottom, top,
    );

}

/// Get position of a rectangle's side, on the X axis if `left` or `right`, or on the Y axis if `top` or `bottom`.
float getSide(Rectangle rectangle, Style.Side side) {

    with (Style.Side)
    return side.predSwitch(
        left,   rectangle.x,
        right,  rectangle.x + rectangle.width,
        top,    rectangle.y,
        bottom, rectangle.y + rectangle.height,

    );

}
