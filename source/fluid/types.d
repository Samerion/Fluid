module fluid.types;

@safe:

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

/// Create a color from RGBA values.
Color color(ubyte r, ubyte g, ubyte b, ubyte a = ubyte.max) pure nothrow {

    Color color;
    color.r = r;
    color.g = g;
    color.b = b;
    color.a = a;
    return color;

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
Color setAlpha(Color color, float alpha) pure nothrow {

    import std.algorithm : clamp;

    color.a = cast(ubyte) clamp(ubyte.max * alpha, 0, ubyte.max);
    return color;

}

Color setAlpha()(Color, int) pure nothrow {

    static assert(false, "Overload setAlpha(Color, int). Explicitly choose setAlpha(Color, float) (0...1 range) or "
        ~ "setAlpha(Color, ubyte) (0...255 range)");

}

/// Set the alpha channel for the given color, as a float.
Color setAlpha(Color color, ubyte alpha) pure nothrow {

    color.a = alpha;
    return color;

}

/// Blend two colors together; apply `top` on top of the `bottom` color. If `top` has maximum alpha, returns `top`. If
/// alpha is zero, returns `bottom`.
///
/// BUG: This function is currently broken and returns incorrect results.
deprecated("alphaBlend is bugged and unused, it will be removed in Fluid 0.8.0")
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
Color multiply(Color a, Color b) nothrow {

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

    /// Width and height of the texture, **in dots**. The meaning of a dot is defined by `dpiX` and `dpiY`
    int width, height;

    /// Dots per inch for the X and Y axis. Defaults to 96, thus making a dot in the texture equivalent to a pixel.
    ///
    /// Applies only if used via `CanvasIO`.
    int dpiX = 96, dpiY = 96;

    /// This number should be incremented after editing the image to signal `CanvasIO` that a change has been made.
    ///
    /// Edits made using `Image`'s methods will *not* bump this number. It has to be incremented manually.
    int revisionNumber;

    /// Create an RGBA image.
    this(Color[] rgbaPixels, int width, int height) pure nothrow {

        this.format = Format.rgba;
        this.rgbaPixels = rgbaPixels;
        this.width = width;
        this.height = height;

    }

    /// Create a paletted image.
    this(PalettedColor[] palettedAlphaPixels, int width, int height) pure nothrow {

        this.format = Format.palettedAlpha;
        this.palettedAlphaPixels = palettedAlphaPixels;
        this.width = width;
        this.height = height;

    }

    /// Create an alpha mask.
    this(ubyte[] alphaPixels, int width, int height) pure nothrow {

        this.format = Format.alpha;
        this.alphaPixels = alphaPixels;
        this.width = width;
        this.height = height;

    }

    Vector2 size() const pure nothrow {
        return Vector2(width, height);
    }

    /// Get texture size as a vector.
    Vector2 canvasSize() const pure nothrow {
        return Vector2(width, height);
    }

    /// Get the size the texture will occupy within the viewport.
    Vector2 viewportSize() const pure nothrow {
        return Vector2(
            width * 96 / dpiX,
            height * 96 / dpiY
        );
    }

    int area() const nothrow {

        return width * height;

    }

    /// Get a palette entry at given index.
    Color paletteColor(PalettedColor pixel) const pure nothrow {

        // Valid index, return the color; Set alpha to match the pixel
        if (pixel.index < palette.length)
            return palette[pixel.index].setAlpha(pixel.alpha);

        // Invalid index, return white
        else
            return color(0xff, 0xff, 0xff, pixel.alpha);

    }

    /// Get data of the image in raw form.
    inout(void)[] data() inout pure nothrow {

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
        const color = paletteColor(entry);

        final switch (format) {

            case Format.rgba:
                rgbaPixels[index] = color;
                return;
            case Format.palettedAlpha:
                palettedAlphaPixels[index] = entry;
                return;
            case Format.alpha:
                alphaPixels[index] = color.a;
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

    /// Convert to an RGBA image.
    ///
    /// Does nothing if the image is already an RGBA image. If it's a paletted image, decodes the colors
    /// using currently assigned palette. If it's an alpha mask, fills the image with white.
    ///
    /// Returns:
    ///     Self if already in RGBA format, or a newly made image by converting the data.
    Image toRGBA() pure nothrow {

        final switch (format) {

            case Format.rgba:
                return this;

            case Format.palettedAlpha:
                auto colors = new Color[palettedAlphaPixels.length];
                foreach (i, pixel; palettedAlphaPixels) {
                    colors[i] = paletteColor(pixel);
                }
                return Image(colors, width, height);

            case Format.alpha:
                auto colors = new Color[alphaPixels.length];
                foreach (i, pixel; alphaPixels) {
                    colors[i] = color(0xff, 0xff, 0xff, pixel);
                }
                return Image(colors, width, height);

        }

    }

    string toString() const pure {

        import std.array;

        Appender!(char[]) text;
        toString(text);
        return text[];

    }

    void toString(Writer)(Writer writer) const {

        import std.conv;
        import std.range;

        put(writer, "Image(");
        put(writer, format.to!string);
        put(writer, ", 0x");
        put(writer, (cast(size_t) data.ptr).toChars!16);
        put(writer, ", ");
        if (format == Format.palettedAlpha) {
            put(writer, "palette: ");
            put(writer, palette.to!string);
            put(writer, ", ");
        }
        put(writer, width.toChars);
        put(writer, "x");
        put(writer, height.toChars);
        put(writer, ", rev ");
        put(writer, revisionNumber.toChars);
        put(writer, ")");

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
