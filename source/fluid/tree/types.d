module fluid.tree.types;

import std.range : ElementType;

@safe:

/// Side array is a static array defining a property separately for each side of a box, for example margin and border
/// size. Order is as follows: `[left, right, top, bottom]`. You can use `Side` to index this array with an enum.
///
/// Because of the default behavior of static arrays, one can set the value for all sides to be equal with a simple
/// assignment: `array = 8`. Additionally, to make it easier to manipulate the box, one may use the `sideX` and `sideY`
/// functions to get a `float[2]` array of the values corresponding to the given axis (which can also be assigned like
/// `array.sideX = 8`) or the `sideLeft`, `sideRight`, `sideTop` and `sideBottom` functions corresponding to the given
/// sides.
enum isSideArray(T) = is(T == X[4], X) && T.length == 4;

/// ditto
enum isSomeSideArray(T) = T.length == 4
    && is(typeof(T.init[0]) == typeof(T.init[1]))
    && is(typeof(T.init[1]) == typeof(T.init[2]))
    && is(typeof(T.init[2]) == typeof(T.init[3]));

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

    return sides[Side.left];

}

/// ditto
auto ref sideRight(T)(return auto ref inout T sides)
if (isSomeSideArray!T) {

    return sides[Side.right];

}

/// ditto
auto ref sideTop(T)(return auto ref inout T sides)
if (isSomeSideArray!T) {

    return sides[Side.top];

}

/// ditto
auto ref sideBottom(T)(return auto ref inout T sides)
if (isSomeSideArray!T) {

    return sides[Side.bottom];

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

    const start = Side.left;
    return sides[start .. start + 2];

}

/// ditto
auto ref sideX(T)(return auto ref inout T sides)
if (isSomeSideArray!T && !isSideArray!T) {

    const start = Side.left;
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

    const start = Side.top;
    return sides[start .. start + 2];

}

/// ditto
auto ref sideY(T)(return auto ref inout T sides)
if (isSomeSideArray!T && !isSideArray!T) {

    const start = Side.top;
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

enum Side {
    left, 
    right, 
    top, 
    bottom,
}

/// Make a style point the other way around
Side reverse(Side side) {

    final switch (side) {
        case Side.left: return Side.right;
        case Side.right: return Side.left;
        case Side.top: return Side.bottom;
        case Side.bottom: return Side.top;
    }

}

/// Get position of a rectangle's side, on the X axis if `left` or `right`, or on the Y axis if `top` or `bottom`.
float getSide(Rectangle rectangle, Side side) {

    final switch (side) {
        case Side.left:   return rectangle.x;
        case Side.right:  return rectangle.x + rectangle.width;
        case Side.top:    return rectangle.y;
        case Side.bottom: return rectangle.y + rectangle.height;
    }

}

unittest {

    const rect = Rectangle(0, 5, 10, 15);

    assert(rect.x == rect.getSide(Side.left));
    assert(rect.y == rect.getSide(Side.top));
    assert(rect.end.x == rect.getSide(Side.right));
    assert(rect.end.y == rect.getSide(Side.bottom));

}

/// Shift the side clockwise (if positive) or counter-clockwise (if negative).
Side shiftSide(Side side, int shift) {

    import std.algorithm : predSwitch;

    // Convert the side to an "angle" — 0 is the top, 1 is right and so on...
    const angle = side.predSwitch(
        Side.top, 0,
        Side.right, 1,
        Side.bottom, 2,
        Side.left, 3,
    );

    // Perform the shift
    const shifted = (angle + shift) % 4;

    // And convert it back
    return shifted.predSwitch(
        0, Side.top,
        1, Side.right,
        2, Side.bottom,
        3, Side.left,
    );

}

unittest {

    assert(shiftSide(Side.left, 0) == Side.left);
    assert(shiftSide(Side.left, 1) == Side.top);
    assert(shiftSide(Side.left, 2) == Side.right);
    assert(shiftSide(Side.left, 4) == Side.left);

    assert(shiftSide(Side.top, 1) == Side.right);

}

/// Get distance between two vectors.
float distance(Vector2 a, Vector2 b) {

    import std.math : sqrt;

    return sqrt(distance2(a, b));

}

/// Get distance between two vectors, squared.
float distance2(Vector2 a, Vector2 b) {

    return (a.x - b.x)^^2 + (a.y - b.y)^^2;

}

/// Convert points to pixels.
/// Params:
///     points = Input value in points.
/// Returns: Given value in pixels.
float pt(float points) {

    // 1 pt = 1/72 in
    // 1 px = 1/96 in
    // 96 px = 72 pt

    return points * 96 / 72;

}

/// Convert pixels to points.
/// Params:
///     points = Input value in pixels.
/// Returns: Given value in points.
float pxToPt(float px) {

    return px * 72 / 96;

}

unittest {

    import std.conv;

    assert(to!int(4.pt * 100) == 533);
    assert(to!int(5.33.pxToPt * 100) == 399);


}

/// Check if the rectangle contains a point.
bool contains(Rectangle rectangle, Vector2 point) {

    return rectangle.x <= point.x
        && point.x < rectangle.x + rectangle.width
        && rectangle.y <= point.y
        && point.y < rectangle.y + rectangle.height;

}

/// Check if the two rectangles overlap.
bool overlap(Rectangle a, Rectangle b) {

    const x = (start(b).x <= a.x && a.x <= end(b).x)
        ||    (start(a).x <= b.x && b.x <= end(a).x);
    const y = (start(b).y <= a.y && a.y <= end(b).y)
        ||    (start(a).y <= b.y && b.y <= end(a).y);

    return x && y;

}

// Extremely useful Rectangle utilities

/// Get the top-left corner of a rectangle.
Vector2 start(Rectangle r) {
    return Vector2(r.x, r.y);
}

/// Get the bottom-right corner of a rectangle.
Vector2 end(Rectangle r) {
    return Vector2(r.x + r.w, r.y + r.h);
}

/// Get the center of a rectangle.
Vector2 center(Rectangle r) {
    return Vector2(r.x + r.w/2, r.y + r.h/2);
}

/// Get the size of a rectangle.
Vector2 size(Rectangle r) {
    return Vector2(r.w, r.h);
}

/// Get a hex code from color.
string toHex(string prefix = "#")(Color color) {

    import std.format;

    // Full alpha, use a six digit code
    if (color.a == 0xff) {

        return format!(prefix ~ "%02x%02x%02x")(color.r, color.g, color.b);

    }

    // Include alpha otherwise
    else return format!(prefix ~ "%02x%02x%02x%02x")(color.tupleof);

}

unittest {

    // No relevant alpha
    assert(color("fff").toHex == "#ffffff");
    assert(color("ffff").toHex == "#ffffff");
    assert(color("ffffff").toHex == "#ffffff");
    assert(color("ffffffff").toHex == "#ffffff");
    assert(color("fafbfc").toHex == "#fafbfc");
    assert(color("123").toHex == "#112233");

    // Alpha set
    assert(color("c0fe").toHex == "#cc00ffee");
    assert(color("1234").toHex == "#11223344");
    assert(color("0000").toHex == "#00000000");
    assert(color("12345678").toHex == "#12345678");

}

/// Create a color from hex code.
Color color(string hexCode)() {

    return color(hexCode);

}

/// ditto
Color color(string hexCode) pure {

    import std.conv: to;
    import std.string : chompPrefix;

    // Remove the # if there is any
    const hex = hexCode.chompPrefix("#");

    Color result;
    result.a = 0xff;

    switch (hex.length) {

        // 4 digit RGBA
        case 4:
            result.a = hex[3..4].to!ubyte(16);
            result.a *= 17;

            // Parse the rest like RGB
            goto case;

        // 3 digit RGB
        case 3:
            result.r = hex[0..1].to!ubyte(16);
            result.g = hex[1..2].to!ubyte(16);
            result.b = hex[2..3].to!ubyte(16);
            result.r *= 17;
            result.g *= 17;
            result.b *= 17;
            break;

        // 8 digit RGBA
        case 8:
            result.a = hex[6..8].to!ubyte(16);
            goto case;

        // 6 digit RGB
        case 6:
            result.r = hex[0..2].to!ubyte(16);
            result.g = hex[2..4].to!ubyte(16);
            result.b = hex[4..6].to!ubyte(16);
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

/// Set the alpha channel for the given color, as a float.
Color setAlpha(Color color, float alpha) {

    import std.algorithm : clamp;

    color.a = cast(ubyte) clamp(ubyte.max * alpha, 0, ubyte.max);
    return color;

}

Color setAlpha()(Color color, int alpha) {

    static assert(false, "Overload setAlpha(Color, int). Explicitly choose setAlpha(Color, float) (0...1 range) or "
        ~ "setAlpha(Color, ubyte) (0...255 range)");

}

/// Set the alpha channel for the given color, as a float.
Color setAlpha(Color color, ubyte alpha) {

    color.a = alpha;
    return color;

}

/// Blend two colors together; apply `top` on top of the `bottom` color. If `top` has maximum alpha, returns `top`. If
/// alpha is zero, returns `bottom`.
///
/// BUG: This function is currently broken and returns incorrect results.
Color alphaBlend(Color bottom, Color top) {

    auto topA = cast(float) top.a / ubyte.max;
    auto bottomA = (1 - topA) * cast(float) bottom.a / ubyte.max;

    return Color(
        cast(ubyte) (bottom.r * bottomA + top.r * topA),
        cast(ubyte) (bottom.g * bottomA + top.g * topA),
        cast(ubyte) (bottom.b * bottomA + top.b * topA),
        cast(ubyte) (bottom.a * bottomA + top.a * topA),
    );

}

/// Multiple color values.
Color multiply(Color a, Color b) {

    return Color(
        cast(ubyte) (a.r * b.r / 255.0),
        cast(ubyte) (a.g * b.g / 255.0),
        cast(ubyte) (a.b * b.b / 255.0),
        cast(ubyte) (a.a * b.a / 255.0),
    );

}

unittest {

    assert(multiply(color!"#fff", color!"#a00") == color!"#a00");
    assert(multiply(color!"#1eff00", color!"#009bdd") == color!"#009b00");
    assert(multiply(color!"#aaaa", color!"#1234") == color!"#0b16222d");

}

/// Generate an image filled with a given color.
///
/// Note: Image data is GC-allocated. Make sure to keep a reference alive when passing to the backend. Do not use
/// `UnloadImage` if using Raylib.
static Image generateColorImage(int width, int height, Color color) {

    // Generate each pixel
    auto data = new Color[width * height];
    data[] = color;

    return Image(data, width, height);

}

/// Generate a paletted image filled with 0-index pixels of given alpha value.
static Image generatePalettedImage(int width, int height, ubyte alpha) {

    auto data = new PalettedColor[width * height];
    data[] = PalettedColor(0, alpha);

    return Image(data, width, height);

}

/// Generate an alpha mask filled with given value.
static Image generateAlphaMask(int width, int height, ubyte value) {

    auto data = new ubyte[width * height];
    data[] = value;

    return Image(data, width, height);

}


/// A paletted pixel, for use in `palettedAlpha` images; Stores images using an index into a palette, along with an
/// alpha value.
struct PalettedColor {

    ubyte index;
    ubyte alpha;

}

/// Image available to the CPU.
struct Image {

    enum Format {

        /// RGBA, 8 bit per channel (32 bits per pixel).
        rgba,

        /// Paletted image with alpha channel (16 bits per pixel)
        palettedAlpha,

        /// Alpha-only image/mask (8 bits per pixel).
        alpha,

    }

    Format format;

    /// Image data. Make sure to access data relevant to the current format.
    ///
    /// Each format has associated data storage. `rgba` has `rgbaPixels`, `palettedAlpha` has `palettedAlphaPixels` and
    /// `alpha` has `alphaPixels`.
    Color[] rgbaPixels;

    /// ditto
    PalettedColor[] palettedAlphaPixels;

    /// ditto
    ubyte[] alphaPixels;

    /// Palette data, if relevant. Access into an invalid palette index is equivalent to full white.
    ///
    /// For `palettedAlpha` images (and `PalettedColor` in general), the alpha value of each color in the palette is
    /// ignored.
    Color[] palette;

    int width, height;

    /// Create an RGBA image.
    this(Color[] rgbaPixels, int width, int height) {

        this.format = Format.rgba;
        this.rgbaPixels = rgbaPixels;
        this.width = width;
        this.height = height;

    }

    /// Create a paletted image.
    this(PalettedColor[] palettedAlphaPixels, int width, int height) {

        this.format = Format.palettedAlpha;
        this.palettedAlphaPixels = palettedAlphaPixels;
        this.width = width;
        this.height = height;

    }

    /// Create an alpha mask.
    this(ubyte[] alphaPixels, int width, int height) {

        this.format = Format.alpha;
        this.alphaPixels = alphaPixels;
        this.width = width;
        this.height = height;

    }

    Vector2 size() const {

        return Vector2(width, height);

    }

    int area() const {

        return width * height;

    }

    /// Get a palette entry at given index.
    Color paletteColor(PalettedColor pixel) const {

        // Valid index, return the color; Set alpha to match the pixel
        if (pixel.index < palette.length)
            return palette[pixel.index].setAlpha(pixel.alpha);

        // Invalid index, return white
        else
            return Color(0xff, 0xff, 0xff, pixel.alpha);

    }

    /// Get data of the image in raw form.
    inout(void)[] data() inout {

        final switch (format) {

            case Format.rgba:
                return rgbaPixels;
            case Format.palettedAlpha:
                return palettedAlphaPixels;
            case Format.alpha:
                return alphaPixels;

        }

    }

    /// Get color at given position. Position must be in image bounds.
    Color get(int x, int y) const {

        const index = y * width + x;

        final switch (format) {

            case Format.rgba:
                return rgbaPixels[index];
            case Format.palettedAlpha:
                return paletteColor(palettedAlphaPixels[index]);
            case Format.alpha:
                return Color(0xff, 0xff, 0xff, alphaPixels[index]);

        }

    }

    unittest {

        auto colors = [
            PalettedColor(0, ubyte(0)),
            PalettedColor(1, ubyte(127)),
            PalettedColor(2, ubyte(127)),
            PalettedColor(3, ubyte(255)),
        ];

        auto image = Image(colors, 2, 2);
        image.palette = [
            Color(0, 0, 0, 255),
            Color(255, 0, 0, 255),
            Color(0, 255, 0, 255),
            Color(0, 0, 255, 255),
        ];

        assert(image.get(0, 0) == Color(0, 0, 0, 0));
        assert(image.get(1, 0) == Color(255, 0, 0, 127));
        assert(image.get(0, 1) == Color(0, 255, 0, 127));
        assert(image.get(1, 1) == Color(0, 0, 255, 255));

    }

    /// Set color at given position. Does nothing if position is out of bounds.
    ///
    /// The `set(int, int, Color)` overload only supports true color images. For paletted images, use
    /// `set(int, int, PalettedColor)`. The latter can also be used for building true color images using a palette, if
    /// one is supplied in the image at the time.
    void set(int x, int y, Color color) {

        if (x < 0 || y < 0) return;
        if (x >= width || y >= height) return;

        const index = y * width + x;

        final switch (format) {

            case Format.rgba:
                rgbaPixels[index] = color;
                return;
            case Format.palettedAlpha:
                assert(false, "Unsupported image format: Cannot `set` pixels by color in a paletted image.");
            case Format.alpha:
                alphaPixels[index] = color.a;
                return;

        }

    }

    /// ditto
    void set(int x, int y, PalettedColor entry) {

        if (x < 0 || y < 0) return;
        if (x >= width || y >= height) return;

        const index = y * width + x;

        final switch (format) {

            case Format.rgba:
                rgbaPixels[index] = paletteColor(entry);
                return;
            case Format.palettedAlpha:
                palettedAlphaPixels[index] = entry;
                return;
            case Format.alpha:
                alphaPixels[index] = paletteColor(entry).a;
                return;

        }

    }

    /// Clear the image, replacing every pixel with given color.
    ///
    /// The `clear(Color)` overload only supports true color images. For paletted images, use `clear(PalettedColor)`.
    /// The latter can also be used for building true color images using a palette, if one is supplied in the image at
    /// the time.
    void clear(Color color) {

        final switch (format) {

            case Format.rgba:
                rgbaPixels[] = color;
                return;
            case Format.palettedAlpha:
                assert(false, "Unsupported image format: Cannot `clear` by color in a paletted image.");
            case Format.alpha:
                alphaPixels[] = color.a;
                return;

        }

    }

    /// ditto
    void clear(PalettedColor entry) {

        const color = paletteColor(entry);

        final switch (format) {

            case Format.rgba:
                rgbaPixels[] = color;
                return;
            case Format.palettedAlpha:
                palettedAlphaPixels[] = entry;
                return;
            case Format.alpha:
                alphaPixels[] = color.a;
                return;

        }

    }

}

// Structures
version (Have_raylib_d) {

    debug (Fluid_BuildMessages) {
        pragma(msg, "Fluid: Using Raylib core structures");
    }

    import raylib;

    alias Rectangle = raylib.Rectangle;
    alias Vector2 = raylib.Vector2;
    alias Color = raylib.Color;

}

else {

    struct Vector2 {

        float x = 0;
        float y = 0;

        mixin Linear;

    }

    struct Rectangle {

        float x, y;
        float width, height;

        alias w = width;
        alias h = height;

    }

    struct Color {

        ubyte r, g, b, a;

    }

    /// `mixin Linear` taken from [raylib-d](https://github.com/schveiguy/raylib-d), reformatted and without Rotor3
    /// support.
    ///
    /// Licensed under the [z-lib license](https://github.com/schveiguy/raylib-d/blob/master/LICENSE).
    private mixin template Linear() {

        private static alias T = typeof(this);
        private import std.traits : FieldNameTuple;

        static T zero() {

            enum fragment = {
                string result;
                static foreach(i; 0 .. T.tupleof.length)
                    result ~= "0,";
                return result;
            }();

            return mixin("T(", fragment, ")");
        }

        static T one() {

            enum fragment = {
                string result;
                static foreach(i; 0 .. T.tupleof.length)
                    result ~= "1,";
                return result;
            }();
            return mixin("T(", fragment, ")");

        }

        inout T opUnary(string op)() if (op == "+" || op == "-") {

            enum fragment = {
                string result;
                static foreach(fn; FieldNameTuple!T)
                    result ~= op ~ fn ~ ",";
                return result;
            }();
            return mixin("T(", fragment, ")");

        }

        inout T opBinary(string op)(inout T rhs) if (op == "+" || op == "-") {

            enum fragment = {
                string result;
                foreach(fn; FieldNameTuple!T)
                    result ~= fn ~ op ~ "rhs." ~ fn ~ ",";
                return result;
            }();
            return mixin("T(", fragment, ")");

        }

        ref T opOpAssign(string op)(inout T rhs) if (op == "+" || op == "-") {

            foreach (field; FieldNameTuple!T)
                mixin(field, op,  "= rhs.", field, ";");

            return this;

        }

        inout T opBinary(string op)(inout float rhs) if (op == "+" || op == "-" || op == "*" || op ==  "/") {

            enum fragment = {
                string result;
                foreach(fn; FieldNameTuple!T)
                    result ~= fn ~ op ~ "rhs,";
                return result;
            }();
            return mixin("T(", fragment, ")");

        }

        inout T opBinaryRight(string op)(inout float lhs) if (op == "+" || op == "-" || op == "*" || op ==  "/") {

            enum fragment = {
                string result;
                foreach(fn; FieldNameTuple!T)
                    result ~= "lhs" ~ op ~ fn ~ ",";
                return result;
            }();
            return mixin("T(", fragment, ")");

        }

        ref T opOpAssign(string op)(inout float rhs) if (op == "+" || op == "-" || op == "*" || op ==  "/") {

            foreach (field; FieldNameTuple!T)
                mixin(field, op, "= rhs;");
            return this;

        }
    }

}
