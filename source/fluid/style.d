///
module fluid.style;

import std.math;
import std.range;
import std.format;
import std.typecons;
import std.algorithm;

import fluid.node;
import fluid.utils;
import fluid.backend;
import fluid.typeface;

public import fluid.theme;
public import fluid.border;
public import fluid.default_theme;
public import fluid.backend : color;


@safe:


/// Contains the style for a node.
struct Style {

    enum Themable;

    enum Side {

        left, right, top, bottom,

    }

    // Text options
    @Themable {

        /// Main typeface to be used for text.
        Typeface typeface;

        alias font = typeface;

        /// Text color.
        Color textColor;

    }

    // Background
    @Themable {

        /// Background color of the node.
        Color backgroundColor;

    }

    // Spacing
    @Themable {

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
        FluidBorder borderStyle;

    }

    // Misc
    public {

        /// Apply tint to all node contents, including children.
        @Themable
        Color tint = color!"fff";

        /// Cursor icon to use while this node is hovered.
        ///
        /// Custom image cursors are not supported yet.
        @Themable
        FluidMouseCursor mouseCursor;

        // TODO set opacity in rules

        /// Get or set node opacity. Value in range [0, 1] — 0 is fully transparent, 1 is fully opaque.
        float opacity() const {

            return tint.a / 255.0;

        }

        /// ditto
        float opacity(float value) {

            tint.a = cast(ubyte) clamp(value * 255, 0, 255);

            return value;

        }

    }

    /// Use `Style.init`.
    @disable this();

    private this(Typeface typeface) {

        this.typeface = typeface;

    }

    /// Get the default, empty style.
    static Style init()
    out (r; r)
    do {

        return Style(Typeface.defaultTypeface);

    }

    static Typeface loadTypeface(string file, int fontSize) @trusted {

        return new FreetypeTypeface(file, fontSize);

    }

    static Typeface loadTypeface(int fontSize) @trusted {

        return new FreetypeTypeface(fontSize);

    }

    alias loadFont = loadTypeface;

    bool opCast(T : bool)() const {

        return this !is Style(null);

    }

    /// Set current DPI.
    void setDPI(Vector2 dpi) {

        // Update the typeface
        if (typeface) {

            typeface.dpi = dpi;

        }

    }

    deprecated("Use Typeface or Text instead. To be removed in 0.7.0.") {

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
        out (r; r.x.isFinite && r.y.isFinite,
            format!"Resulting text space must be finite: %s"(r))
        do {

            return typeface.measure(availableSpace, text, wrap);

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
        void drawText(ref Image image, Rectangle rect, string text, bool wrap = true) const {

            typeface.draw(image, rect, text, textColor, wrap);

        }

        /// ditto
        void drawText(ref Image image, Rectangle rect, string text, Color color, bool wrap = true) const {

            typeface.draw(image, rect, text, color, wrap);

        }

    }

    /// Draw the background
    void drawBackground(FluidBackend backend, Rectangle rect) const @trusted {

        backend.drawRectangle(rect, backgroundColor);

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

/// Side array is a static array defining a property separately for each side of a box, for example margin and border
/// size. Order is as follows: `[left, right, top, bottom]`. You can use `Style.Side` to index this array with an enum.
///
/// Because of the default behavior of static arrays, one can set the value for all sides to be equal with a simple
/// assignment: `array = 8`. Additionally, to make it easier to manipulate the box, one may use the `sideX` and `sideY`
/// functions to get a `uint[2]` array of the values corresponding to the given axis (which can also be assigned like
/// `array.sideX = 8`) or the `sideLeft`, `sideRight`, `sideTop` and `sideBottom` functions corresponding to the given
/// sides.
enum isSideArray(T) = is(T == X[4], X);

/// ditto
enum isSomeSideArray(T) = isSideArray!T
    || (is(T == Field!(name, U), string name, U) && isSideArray!U);

///
unittest {

    uint[4] sides;
    static assert(isSideArray!(uint[4]));

    sides.sideX = 4;

    assert(sides.sideLeft == sides.sideRight);
    assert(sides.sideLeft == 4);

    sides = 8;
    assert(sides == [8, 8, 8, 8]);
    assert(sides.sideX == sides.sideY);

}

/// Get a reference to the left, right, top or bottom side of the given side array.
auto ref sideLeft(T)(return auto ref inout T sides)
if (isSomeSideArray!T) {

    return sides[Style.Side.left];

}

/// ditto
auto ref sideRight(T)(return auto ref inout T sides)
if (isSomeSideArray!T) {

    return sides[Style.Side.right];

}

/// ditto
auto ref sideTop(T)(return auto ref inout T sides)
if (isSomeSideArray!T) {

    return sides[Style.Side.top];

}

/// ditto
auto ref sideBottom(T)(return auto ref inout T sides)
if (isSomeSideArray!T) {

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
ref inout(ElementType!T[2]) sideX(T)(return ref inout T sides)
if (isSideArray!T) {

    const start = Style.Side.left;
    return sides[start .. start + 2];

}

/// ditto
auto ref sideX(T)(return auto ref inout T sides)
if (isSomeSideArray!T && !isSideArray!T) {

    const start = Style.Side.left;
    return sides[start .. start + 2];

}

/// Get a reference to the Y axis for the given side array.
ref inout(ElementType!T[2]) sideY(T)(return ref inout T sides)
if (isSideArray!T) {

    const start = Style.Side.top;
    return sides[start .. start + 2];

}

/// ditto
auto ref sideY(T)(return auto ref inout T sides)
if (isSomeSideArray!T && !isSideArray!T) {

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

unittest {

    const rect = Rectangle(0, 5, 10, 15);

    assert(rect.x == rect.getSide(Style.Side.left));
    assert(rect.y == rect.getSide(Style.Side.top));
    assert(rect.end.x == rect.getSide(Style.Side.right));
    assert(rect.end.y == rect.getSide(Style.Side.bottom));

}

unittest {

    import fluid.frame;
    import fluid.structs;

    auto io = new HeadlessBackend;
    auto myTheme = nullTheme.derive(
        rule!Frame(
            Rule.backgroundColor = color!"fff",
            Rule.tint = color!"aaaa",
        ),
    );
    auto root = vframe(
        layout!(1, "fill"),
        myTheme,
        vframe(
            layout!(1, "fill"),
            vframe(
                layout!(1, "fill"),
                vframe(
                    layout!(1, "fill"),
                )
            ),
        ),
    );

    root.io = io;
    root.draw();

    auto rect = Rectangle(0, 0, 800, 600);
    auto bg = color!"fff";

    // Background rectangles — all covering the same area, but with fading color and transparency
    io.assertRectangle(rect, bg = multiply(bg, color!"aaaa"));
    io.assertRectangle(rect, bg = multiply(bg, color!"aaaa"));
    io.assertRectangle(rect, bg = multiply(bg, color!"aaaa"));
    io.assertRectangle(rect, bg = multiply(bg, color!"aaaa"));

}

unittest {

    import fluid.frame;
    import fluid.structs;

    auto io = new HeadlessBackend;
    auto myTheme = nullTheme.derive(
        rule!Frame(
            Rule.backgroundColor = color!"fff",
            Rule.tint = color!"aaaa",
            Rule.border.sideRight = 1,
            Rule.borderStyle = colorBorder(color!"f00"),
        )
    );
    auto root = vframe(
        layout!(1, "fill"),
        myTheme,
        vframe(
            layout!(1, "fill"),
            vframe(
                layout!(1, "fill"),
                vframe(
                    layout!(1, "fill"),
                )
            ),
        ),
    );

    root.io = io;
    root.draw();

    auto bg = color!"fff";

    // Background rectangles — reducing in size every pixel as the border gets added
    io.assertRectangle(Rectangle(0, 0, 799, 600), bg = multiply(bg, color!"aaaa"));
    io.assertRectangle(Rectangle(0, 0, 798, 600), bg = multiply(bg, color!"aaaa"));
    io.assertRectangle(Rectangle(0, 0, 797, 600), bg = multiply(bg, color!"aaaa"));
    io.assertRectangle(Rectangle(0, 0, 796, 600), bg = multiply(bg, color!"aaaa"));

    auto border = color!"f00";

    // Border rectangles
    io.assertRectangle(Rectangle(799, 0, 1, 600), border = multiply(border, color!"aaaa"));
    io.assertRectangle(Rectangle(798, 0, 1, 600), border = multiply(border, color!"aaaa"));
    io.assertRectangle(Rectangle(797, 0, 1, 600), border = multiply(border, color!"aaaa"));
    io.assertRectangle(Rectangle(796, 0, 1, 600), border = multiply(border, color!"aaaa"));

}
