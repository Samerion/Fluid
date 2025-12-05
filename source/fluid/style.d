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
import fluid.text.typeface;
import fluid.text.freetype;

import fluid.io.canvas;

public import fluid.theme : Theme, Selector, rule, Rule, when, WhenRule, children, ChildrenRule,
    Field, Breadcrumbs;
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
        ///
        /// Changing the typeface requires a resize.
        Typeface typeface;

        alias font = typeface;

        /// Size of the font in use, in pixels.
        ///
        /// Changing the size requires a resize.
        float fontSize = 14.pt;

        /// Text color.
        auto textColor = Color(0, 0, 0, 0);

    }

    // Background & content
    @Themable {

        /// Color of lines belonging to the node, especially important to separators and sliders.
        auto lineColor = Color(0, 0, 0, 0);

        /// Background color of the node.
        auto backgroundColor = Color(0, 0, 0, 0);

        /// Background color for selected text.
        auto selectionBackgroundColor = Color(0, 0, 0, 0);

    }

    // Spacing
    @Themable {

        /// Margin (outer margin) of the node. `[left, right, top, bottom]`.
        ///
        /// Updating margins requires a resize.
        ///
        /// See: `isSideArray`.
        float[4] margin = 0;

        /// Border size, placed between margin and padding. `[left, right, top, bottom]`.
        ///
        /// Updating border requires a resize.
        ///
        /// See: `isSideArray`
        float[4] border = 0;

        /// Padding (inner margin) of the node. `[left, right, top, bottom]`.
        ///
        /// Updating padding requires a resize.
        ///
        /// See: `isSideArray`
        float[4] padding = 0;

        /// Margin/gap between two neighboring elements; for container nodes that support it.
        ///
        /// Updating the gap requires a resize.
        float[2] gap = 0;

        /// Border style to use.
        ///
        /// Updating border requires a resize.
        FluidBorder borderStyle;

    }

    // Misc
    public {

        /// Apply tint to all node contents, including children.
        @Themable
        Color tint = Color(0xff, 0xff, 0xff, 0xff);

        /// Cursor icon to use while this node is hovered.
        ///
        /// Custom image cursors are not supported yet.
        @Themable
        FluidMouseCursor mouseCursor;

        /// Additional information for the node the style applies to.
        ///
        /// Ignored if mismatched.
        @Themable
        Node.Extra extra;

        /// Get or set node opacity. Value in range [0, 1] — 0 is fully transparent, 1 is fully opaque.
        float opacity() const {

            return tint.a / 255.0f;

        }

        /// ditto
        float opacity(float value) {

            tint.a = cast(ubyte) clamp(value * ubyte.max, ubyte.min, ubyte.max);

            return value;

        }

    }

    public {

        /// Breadcrumbs associated with this style. Used to keep track of tree-aware theme selectors, such as
        /// `children`. Does not include breadcrumbs loaded by parent nodes.
        Breadcrumbs breadcrumbs;

    }

    private this(Typeface typeface) {

        this.typeface = typeface;

    }

    static Typeface defaultTypeface() {

        return FreetypeTypeface.defaultTypeface;

    }

    static Typeface loadTypeface(string file) {

        return new FreetypeTypeface(file);

    }

    alias loadFont = loadTypeface;

    bool opCast(T : bool)() const {

        return this !is Style(null);

    }

    bool opEquals(const Style other) const @trusted {

        // @safe: FluidBorder and Typeface are required to provide @safe opEquals.
        // D doesn't check for opEquals on interfaces, though.
        return this.tupleof == other.tupleof;

    }

    /// Set current DPI.
    void setDPI(Vector2 dpi) {

        getTypeface.setSize(dpi, fontSize);

    }

    /// Get current typeface, or fallback to default.
    Typeface getTypeface() {

        return either(typeface, defaultTypeface);

    }

    const(Typeface) getTypeface() const {

        return either(typeface, defaultTypeface);

    }

    /// Draw the background & border.
    void drawBackground(FluidBackend backend, Rectangle rect) const {

        backend.drawRectangle(rect, backgroundColor);

        // Add border if active
        if (borderStyle) {

            borderStyle.apply(backend, rect, border);

        }

    }

    /// ditto
    void drawBackground(FluidBackend backend, CanvasIO io, Rectangle rect) const {

        // New I/O system used
        if (io) {

            const ioBorder = cast(const FluidIOBorder) borderStyle;

            io.drawRectangle(rect, backgroundColor);

            // Draw border if present and compatible
            if (ioBorder) {
                ioBorder.apply(io, rect, border);
            }

        }

        // Old Backend system
        else drawBackground(backend, rect);

    }

    /// Draw a line.
    void drawLine(FluidBackend backend, Vector2 start, Vector2 end) const {

        backend.drawLine(start, end, lineColor);

    }

    /// ditto
    void drawLine(FluidBackend backend, CanvasIO canvasIO, Vector2 start, Vector2 end) const {

        // New I/O system used
        if (canvasIO) {

            canvasIO.drawLine(start, end, 1, lineColor);

        }

        else drawLine(backend, start, end);

    }

    /// Get a side array holding both the regular margin and the border.
    float[4] fullMargin() const {

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
    float[4] totalMargin() const {

        float[4] ret = margin[] + border[] + padding[];
        return ret;

    }

    /// Crop the given box by reducing its size on all sides.
    static Vector2 cropBox(Vector2 size, float[4] sides) {

        size.x = max(0, size.x - sides.sideLeft - sides.sideRight);
        size.y = max(0, size.y - sides.sideTop - sides.sideBottom);

        return size;

    }

    /// ditto
    static Rectangle cropBox(Rectangle rect, float[4] sides) {

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
/// functions to get a `float[2]` array of the values corresponding to the given axis (which can also be assigned like
/// `array.sideX = 8`) or the `sideLeft`, `sideRight`, `sideTop` and `sideBottom` functions corresponding to the given
/// sides.
enum isSideArray(T) = is(T == X[4], X) && T.length == 4;

/// ditto
enum isSomeSideArray(T) = isSideArray!T
    || (is(T == Field!(name, U), string name, U) && isSideArray!U);

///
unittest {

    float[4] sides;
    static assert(isSideArray!(float[4]));

    sides.sideX = 4;

    assert(sides.sideLeft == sides.sideRight);
    assert(sides.sideLeft == 4);

    sides = 8;
    assert(sides == [8, 8, 8, 8]);
    assert(sides.sideX == sides.sideY);

}

/// An axis array is similar to a size array, but does not distinguish between invididual directions on a single axis.
/// Thus, it contains only two values, one for the X axis, and one for the Y axis.
///
/// `sideX` and `sideY` can be used to access individual items of an axis array by name.
enum isAxisArray(T) = is(T == X[2], X) && T.length == 2;

static assert(!isSideArray!(float[2]));
static assert( isSideArray!(float[4]));

static assert( isAxisArray!(float[2]));
static assert(!isAxisArray!(float[4]));

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

    float[4] sides = [8, 0, 4, 2];

    assert(sides.sideRight == 0);

    sides.sideRight = 8;
    sides.sideBottom = 4;

    assert(sides == [8, 8, 4, 4]);

}

/// Get a reference to the X axis for the given side or axis array.
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

/// ditto
ref inout(ElementType!T) sideX(T)(return ref inout T sides)
if (isAxisArray!T) {

    return sides[0];

}

/// Get a reference to the Y axis for the given side or axis array.
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

/// ditto
ref inout(ElementType!T) sideY(T)(return ref inout T sides)
if (isAxisArray!T) {

    return sides[1];

}

/// Assigning values to an axis of a side array.
unittest {

    float[4] sides = [1, 2, 3, 4];

    assert(sides.sideX == [sides.sideLeft, sides.sideRight]);
    assert(sides.sideY == [sides.sideTop, sides.sideBottom]);

    sides.sideX = 8;

    assert(sides == [8, 8, 3, 4]);

    sides.sideY = sides.sideBottom;

    assert(sides == [8, 8, 4, 4]);

}

/// Operating on an axis array.
@("sideX/sideY work on axis arrays")
unittest {

    float[2] sides;

    sides.sideX = 1;
    sides.sideY = 2;

    assert(sides == [1, 2]);

    assert(sides.sideX == 1);
    assert(sides.sideY == 2);

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

@("Legacy: Style.tint stacks (migrated)")
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

@("Legacy: Border occupies and takes space (abandoned)")
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
    io.assertRectangle(Rectangle(0, 0, 800, 600), bg = multiply(bg, color!"aaaa"));
    io.assertRectangle(Rectangle(0, 0, 799, 600), bg = multiply(bg, color!"aaaa"));
    io.assertRectangle(Rectangle(0, 0, 798, 600), bg = multiply(bg, color!"aaaa"));
    io.assertRectangle(Rectangle(0, 0, 797, 600), bg = multiply(bg, color!"aaaa"));

    auto border = color!"f00";

    // Border rectangles
    io.assertRectangle(Rectangle(799, 0, 1, 600), border = multiply(border, color!"aaaa"));
    io.assertRectangle(Rectangle(798, 0, 1, 600), border = multiply(border, color!"aaaa"));
    io.assertRectangle(Rectangle(797, 0, 1, 600), border = multiply(border, color!"aaaa"));
    io.assertRectangle(Rectangle(796, 0, 1, 600), border = multiply(border, color!"aaaa"));

}

/// Check if a rectangle is located above (`isAbove`), below (`isBelow`), to the left (`isToLeft`) or to the right
/// (`isToRight`) of another rectangle.
///
/// The four functions wrap `isBeyond` which accepts a `Side` argument to specify direction at runtime.
///
/// Params:
///     subject   = Rectangle subject to the query. "Is *this* rectangle above the other?"
///     reference = Rectangle used as reference.
///     side      = If using `isBeyond`, the direction the subject is expected to be in relation to the other.
bool isAbove(Rectangle subject, Rectangle reference) {
    return isBeyond(subject, reference, Style.Side.top);
}

/// ditto
bool isBelow(Rectangle subject, Rectangle reference) {
    return isBeyond(subject, reference, Style.Side.bottom);
}

/// ditto
bool isToLeft(Rectangle subject, Rectangle reference) {
    return isBeyond(subject, reference, Style.Side.left);
}

/// ditto
bool isToRight(Rectangle subject, Rectangle reference) {
    return isBeyond(subject, reference, Style.Side.right);
}

/// ditto
bool isBeyond(Rectangle subject, Rectangle reference, Style.Side side) {

    // Distance between box sides facing each other.
    // To illustrate, we're checking if the subject is to the right of the reference box:
    // (side = right, side.reverse = left)
    //
    // ↓ reference     ↓ subject
    // +------+        +======+
    // |      |        |      |
    // |      | ~~~~~~ |      |
    // |      |        |      |
    // +------+        +======+
    //   side ↑        ↑ side.reverse
    const distanceExternal = reference.getSide(side) - subject.getSide(side.reverse);

    // Distance between corresponding box sides.
    //
    // ↓ reference     ↓ subject
    // +------+        +======+
    // |      |        :      |
    // |      | ~~~~~~~~~~~~~ |
    // |      |        :      |
    // +------+        +======+
    //   side ↑          side ↑
    const distanceInternal = reference.getSide(side) - subject.getSide(side);

    // The condition for the return value to be true, is for distanceInternal to be greater than distanceExternal.
    // This is not the case in the opposite situation.
    //
    // For example, if we're checking if the subject is on the *right* of reference:
    //
    // trueish scenario:                                 falseish scenario:
    // Subject is to the right of reference              Subject is the left of reference
    //
    // ↓ reference     ↓ subject                         ↓ subject       ↓ reference
    // +------+        +======+                          +======+        +------+
    // |      | ~~~~~~ :      | external                 | ~~~~~~~~~~~~~~~~~~~~ | external
    // |      |        :      |    <                     |      :        :      |    >
    // |      | ~~~~~~~~~~~~~ | internal                 |      : ~~~~~~~~~~~~~ | internal
    // +------+        +======+                          +======+        +------+
    //   side ↑        ↑ side.reverse                      side ↑          side ↑
    const condition = abs(distanceInternal) > abs(distanceExternal);

    // ↓ subject                There is an edgecase though. If one box entirely overlaps the other on one axis,
    // +====================+   it will be simultaneously to the left, and to the right, creating an ambiguity.
    // |   ↓ reference      |
    // |   +------------+   |   This is unwated in scenarios like focus switching. A scrollbar placed to the right
    // |   |            |   |   of the page, should be focused by the right key, not by up or down.
    // +===|            |===+
    //     |            |       For this reason, we require both `distanceInternal` and `distanceExternal` to have
    //     +------------+       the same sign, as it normally would, but not in case of an overlap.
    return condition
        && distanceInternal * distanceExternal >= 0;

}

/// Comparing two rectangles laid out in a column.
unittest {

    const rect1 = Rectangle(0,  0, 10, 10);
    const rect2 = Rectangle(0, 20, 10, 10);

    assert(rect1.isAbove(rect2));
    assert(rect2.isBelow(rect1));

    assert(!rect1.isBelow(rect2));
    assert(!rect2.isAbove(rect1));
    assert(!rect1.isToLeft(rect2));
    assert(!rect2.isToLeft(rect1));
    assert(!rect1.isToRight(rect2));
    assert(!rect2.isToRight(rect1));

}

/// Comparing two rectangles laid out in a row.
unittest {

    const rect1 = Rectangle( 0, 0, 10, 10);
    const rect2 = Rectangle(20, 0, 10, 10);

    assert(rect1.isToLeft(rect2));
    assert(rect2.isToRight(rect1));

    assert(!rect1.isToRight(rect2));
    assert(!rect2.isToLeft(rect1));
    assert(!rect1.isAbove(rect2));
    assert(!rect2.isAbove(rect1));
    assert(!rect1.isBelow(rect2));
    assert(!rect2.isBelow(rect1));

}
