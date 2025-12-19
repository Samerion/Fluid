/// This module provides font rendering using the Freetype C library.
module fluid.text.freetype;

import bindbc.freetype;

import std.string;

import fluid.utils;
import fluid.types;
import fluid.text.rope;
import fluid.text.typeface;

@safe:

version (BindFT_Static) {
    debug (Fluid_BuildMessages) {
        pragma(msg, "Fluid: Using static freetype");
    }
}
else {
    version = BindFT_Dynamic;
    debug (Fluid_BuildMessages) {
        pragma(msg, "Fluid: Using dynamic freetype");
    }
}

/// Represents a freetype2-powered typeface.
class FreetypeTypeface : Typeface {

    public {

        /// Underlying face.
        FT_Face face;

        /// Adjust line height. `1` uses the original line height, `2` doubles it.
        float lineHeightFactor = 1;

    }

    protected {

        /// Cache for character sizes. The key is text size in dots.
        Vector2[dchar][int] advanceCache;
        Vector2[dchar] currentAdvanceCache;

    }

    private {

        /// If true, this typeface has been loaded using this class, making the class responsible for freeing the font.
        bool _isOwner;

        /// Font size loaded (in pixels).
        float _size;

        /// Current DPI set for the typeface.
        int _dpiX, _dpiY;

        int _indentWidth;

    }

    static FreetypeTypeface defaultTypeface;

    static this() @trusted {

        // Set the default typeface
        FreetypeTypeface.defaultTypeface = new FreetypeTypeface;

    }

    /// Load the default typeface.
    this() @trusted {

        static typefaceFile = cast(ubyte[]) import("ruda-regular.ttf");
        const typefaceSize = cast(int) typefaceFile.length;

        // Load the font
        if (auto error = FT_New_Memory_Face(freetype, typefaceFile.ptr, typefaceSize, 0, &face)) {

            assert(false, format!"Failed to load default Fluid typeface, error no. %s"(error));

        }

        // Mark self as the owner
        this.isOwner = true;
        this.lineHeightFactor = 1.16;

    }

    /// Params:
    ///     face = Existing freetype2 typeface to use.
    this(FT_Face face) {

        this.face = face;

    }

    /// Load a font from a file.
    /// Params:
    ///     filename = Filename of the font file.
    this(string filename) @trusted {

        this._isOwner = true;

        // TODO proper exceptions
        if (auto error = FT_New_Face(freetype, filename.toStringz, 0, &this.face)) {

            throw new Exception(format!"Failed to load `%s`, error no. %s"(filename, error));

        }

    }

    ~this() @trusted {

        // Ignore if the resources used by the class have been borrowed
        if (!_isOwner) return;

        FT_Done_Face(face);

    }

    /// Instances of Typeface have to be comparable in a memory-safe manner.
    override bool opEquals(const Object object) @safe const {

        return this is object;

    }

    ref inout(int) indentWidth() inout {
        return _indentWidth;
    }
    bool isOwner() const {
        return _isOwner;
    }
    bool isOwner(bool value) @system {
        return _isOwner = value;
    }

    long glyphCount() const {

        return face.num_glyphs;

    }

    /// Get initial pen position.
    Vector2 penPosition() const {

        return Vector2(0, face.size.metrics.ascender) / 64;

    }

    /// Line height.
    int lineHeight() const {

        // +1 is an error margin
        return cast(int) (face.size.metrics.height * lineHeightFactor / 64) + 1;

    }

    Vector2 dpi() const {
        return Vector2(_dpiX, _dpiY);
    }

    void setSize(Vector2 dpi, float size) @trusted {

        const dpiX = cast(int) dpi.x;
        const dpiY = cast(int) dpi.y;

        // Ignore if there's no change
        if (dpiX == _dpiX && dpiY == _dpiY && size == _size) return;

        _dpiX = dpiX;
        _dpiY = dpiY;
        _size = size;

        const dotsY = cast(int) (size * dpi.y / 96);
        const size64 = cast(int) (size.pxToPt * 64 + 1);

        // Set current advance cache to matching font size
        currentAdvanceCache = advanceCache.require(dotsY, ['\0': Vector2.init]);
        assert(currentAdvanceCache);

        // dunno why, but FT_Set_Char_Size yields better results, kerning specifically, than FT_Set_Pixel_Sizes
        version (all) {
            const error = FT_Set_Char_Size(face, 0, size64, dpiX, dpiY);
        }

        // Load size
        else {
            const dotsX = cast(int) (size * dpi.x / 96);
            const dotsY = cast(int) (size * dpi.y / 96);
            const error = FT_Set_Pixel_Sizes(face, dotsX, dotsY);
        }

        // Test for errors
        if (error) {

            throw new Exception(
                format!"Failed to load font at size %s at DPI %sx%s, error no. %s"(size, dpiX, dpiY, error)
            );

        }

    }

    Vector2 advance(dchar glyph) @trusted {

        assert(_dpiX && _dpiY, "Font DPI hasn't been set");

        // Return the stored value if the result is cached
        if (auto result = glyph in currentAdvanceCache) {

            return *result;

        }

        // Load the glyph
        if (auto error = FT_Load_Char(cast(FT_Face) face, glyph, FT_LOAD_DEFAULT)) {

            return currentAdvanceCache[glyph] = Vector2(0, 0);

        }

        // Advance the cursor position
        // TODO RTL layouts
        return currentAdvanceCache[glyph] = Vector2(face.glyph.advance.tupleof) / 64;

    }

    /// Draw a line of text
    void drawLine(ref Image target, ref Vector2 penPosition, const Rope text, ubyte paletteIndex) const @trusted {

        assert(_dpiX && _dpiY, "Font DPI hasn't been set");

        foreach (glyph; text.byDchar) {

            // Tab character
            if (glyph == '\t') {

                drawTab(penPosition);
                continue;

            }

            // Load the glyph
            if (auto error = FT_Load_Char(cast(FT_Face) face, glyph, FT_LOAD_RENDER)) {

                continue;

            }

            const bitmap = face.glyph.bitmap;

            assert(bitmap.pixel_mode == FT_PIXEL_MODE_GRAY);

            // Draw it to the image
            foreach (y; 0..bitmap.rows) {

                foreach (x; 0..bitmap.width) {

                    // Each pixel is a single byte
                    const pixel = *cast(ubyte*) (bitmap.buffer + bitmap.pitch*y + x);

                    const targetX = cast(int) penPosition.x + face.glyph.bitmap_left + x;
                    const targetY = cast(int) penPosition.y - face.glyph.bitmap_top + y;

                    // Don't draw pixels out of bounds
                    if (targetX >= target.width || targetY >= target.height) continue;

                    // Choose the stronger color
                    const ubyte oldAlpha = target.get(targetX, targetY).a;
                    const ubyte newAlpha = ubyte.max * pixel / pixel.max;

                    if (newAlpha >= oldAlpha)
                        target.set(targetX, targetY, PalettedColor(paletteIndex, newAlpha));

                }

            }

            // Advance pen positon
            penPosition += Vector2(face.glyph.advance.tupleof) / 64;

        }

    }

}

unittest {

    auto image = generateColorImage(10, 10, color("#fff"));
    auto tf = FreetypeTypeface.defaultTypeface;
    tf.setSize(Vector2(96, 96), 14.pt);
    tf.indentWidth = cast(int) (tf.advance(' ').x * 4);

    Vector2 measure(string text) {

        Vector2 penPosition;
        tf.drawLine(image, penPosition, Rope(text), 0);
        return penPosition;

    }

    // Draw 4 spaces to use as reference in the test
    const indentReference = measure("    ");

    assert(indentReference.x > 0);
    assert(indentReference.x == tf.advance(' ').x * 4);
    assert(indentReference.x == tf.indentWidth);

    assert(measure("\t") == indentReference);
    assert(measure("a\t") == indentReference);

    const doubleAIndent = measure("aa").x > indentReference.x
        ? 2
        : 1;
    const tripleAIndent = measure("aaa").x > doubleAIndent * indentReference.x
        ? doubleAIndent + 1
        : doubleAIndent;

    assert(measure("aa\t")  == indentReference * doubleAIndent);
    assert(measure("aaa\t") == indentReference * tripleAIndent);
    assert(measure("\t\t") == indentReference * 2);
    assert(measure("a\ta\t") == indentReference * 2);
    assert(measure("aa\taa\t") == 2 * indentReference * doubleAIndent);

}

version (BindFT_Dynamic)
shared static this() @system {

    // Ignore if freetype was already loaded
    if (isFreeTypeLoaded) return;

    // Load freetype
    FTSupport ret = loadFreeType();

    // Check version
    if (ret != ftSupport) {

        if (ret == FTSupport.noLibrary) {

            assert(false, "freetype2 failed to load");

        }
        else if (FTSupport.badLibrary) {

            assert(false, format!"found freetype2 is of incompatible version %s (needed %s)"(ret, ftSupport));

        }

    }

}

/// Get the thread-local freetype reference.
FT_Library freetype() @trusted {

    static FT_Library library;

    // Load the library
    if (library != library.init) return library;

    if (auto error = FT_Init_FreeType(&library)) {

        assert(false, format!"Failed to load freetype2: %s"(error));

    }

    return library;

}
