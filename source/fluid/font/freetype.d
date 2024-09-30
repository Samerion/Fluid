/// This module provides Freetype text rendering support for Fluid.
///
/// To compile with this module, [set `fluid:font` configuration][1] to `freetype`. This is set by default.
/// To toggle this module using a version, use `Fluid_Freetype`.
///
/// [1]: https://dub.pm/dub-reference/build_settings/#subconfigurations
module fluid.font.freetype;

version (Fluid_Freetype):
version (Have_fluid_font):

import bindbc.freetype;

import std.format;
import std.string;

import fluid.font;
import fluid.rope;
import fluid.backend;

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

@safe:

version (Fluid_DefaultFreetype) {

    shared static this() {

        loadTypefaceFromFile = (file, fontSize) 
            => new FreetypeTypeface(file, fontSize);

        loadDefaultTypeface = (fontSize) 
            => new FreetypeTypeface(fontSize);

        getDefaultTypeface = ()
            => FreetypeTypeface.defaultTypeface;

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

        /// Cache for character sizes.
        Vector2[dchar] advanceCache;

    }

    private {

        /// If true, this typeface has been loaded using this class, making the class responsible for freeing the font.
        bool _isOwner;

        /// Font size loaded (points).
        float _size;

        /// Current DPI set for the typeface.
        int _dpiX, _dpiY;

        int _indentWidth;

    }

    static FreetypeTypeface defaultTypeface;

    static this() @trusted {

        // Set the default typeface
        FreetypeTypeface.defaultTypeface = new FreetypeTypeface(14);

    }

    /// Load the default typeface
    this(float size) @trusted {

        static typefaceFile = cast(ubyte[]) import("ruda-regular.ttf");
        const typefaceSize = cast(int) typefaceFile.length;

        // Load the font
        if (auto error = FT_New_Memory_Face(freetype, typefaceFile.ptr, typefaceSize, 0, &face)) {

            assert(false, format!"Failed to load default Fluid typeface at size %s, error no. %s"(size, error));

        }

        // Mark self as the owner
        this._size = size;
        this.isOwner = true;
        this.lineHeightFactor = 1.16;

    }

    /// Use an existing freetype2 font.
    this(FT_Face face, float size) {

        this.face = face;
        this._size = size;

    }

    /// Load a font from a file.
    /// Params:
    ///     backend  = I/O Fluid backend, used to adjust the scale of the font.
    ///     filename = Filename of the font file.
    ///     size     = Size of the font to load (in points).
    this(string filename, float size) @trusted {

        this._isOwner = true;
        this._size = size;

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

    Vector2 dpi(Vector2 dpi) @trusted {

        const dpiX = cast(int) dpi.x;
        const dpiY = cast(int) dpi.y;

        // Ignore if there's no change
        if (dpiX == _dpiX && dpiY == _dpiY) return dpi;

        _dpiX = dpiX;
        _dpiY = dpiY;

        auto intSize = cast(int) (_size * 64 + 1);

        // Load size
        if (auto error = FT_Set_Char_Size(face, 0, intSize, dpiX, dpiY)) {

            throw new Exception(
                format!"Failed to load font at size %s at DPI %sx%s, error no. %s"(_size, dpiX, dpiY, error)
            );

        }

        // Clear the cache
        advanceCache.clear();

        return dpi;

    }

    /// Get advance vector for the given glyph
    Vector2 advance(dchar glyph) @trusted {

        assert(_dpiX && _dpiY, "Font DPI hasn't been set");

        // Return the stored value if the result is cached
        if (auto result = glyph in advanceCache) {

            return *result;

        }

        // Load the glyph
        if (auto error = FT_Load_Char(cast(FT_FaceRec*) face, glyph, FT_LOAD_DEFAULT)) {

            return advanceCache[glyph] = Vector2(0, 0);

        }

        // Advance the cursor position
        // TODO RTL layouts
        return advanceCache[glyph] = Vector2(face.glyph.advance.tupleof) / 64;

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
            if (auto error = FT_Load_Char(cast(FT_FaceRec*) face, glyph, FT_LOAD_RENDER)) {

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
    tf.dpi = Vector2(96, 96);
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
