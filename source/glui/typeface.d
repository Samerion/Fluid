module glui.typeface;

import raylib;
import bindbc.freetype;

import std.string;


@safe:


/// Represents a single typeface in Glui.
interface Typeface {

    /// List glyphs  in the typeface.
    long glyphCount() const;

    /// Get initial pen position.
    Vector2 penPosition() const;

    /// Get line height.
    int lineHeight() const;

    /// Get advance vector for the given glyph
    Vector2 advance(dchar glyph) const;

    /// Draw a line of text
    /// Note: This API is unstable and might change over time.
    /// Returns: Change in pen position.
    void drawLine(ref Image target, ref Vector2 penPosition, string text, Color tint) const;

    /// Measure space the given text would span.
    final Vector2 measureText(Vector2 availableSpace, string text, bool wrap = true) const {

        auto span = Vector2(0, lineHeight);

        // TODO multiline
        // TODO don't fail on decoding errors
        foreach (dchar glyph; text) {

            span += advance(glyph);

        }

        return span;

    }

    /// Draw text within the given rectangle in the image.
    final void draw(ref Image image, Rectangle rectangle, string text, Color tint, bool wrap = true) const {

        auto pen = penPosition + Vector2(rectangle.x, rectangle.y);

        // TODO multiline
        // TODO decoding errors
        drawLine(image, pen, text, tint);

    }

}

/// Represents a freetype2-powered typeface.
class FreetypeTypeface : Typeface {

    public {

        /// Underlying face.
        FT_Face face;

    }

    /// If true, this typeface has been loaded using this class, making the class responsible for freeing the font.
    protected bool isOwner;

    /// Use an existing freetype2 font.
    this(FT_Face face) {

        this.face = face;
        this.isOwner = false;

    }

    /// Load a font from a file.
    /// Params:
    ///     filename = Filename of the font file.
    ///     size     = Size of the font to load (in points).
    this(string filename, int size) @trusted {

        import glui.utils;

        const scale = hidpiScale * 96;

        this.isOwner = true;

        // TODO proper exceptions
        if (auto error = FT_New_Face(freetype, filename.toStringz, 0, &this.face)) {

            throw new Exception(format!"Failed to load `%s`, error no. %s"(filename, error));

        }

        // Load size
        if (auto error = FT_Set_Char_Size(face, 0, size*64, cast(int) scale.x, cast(int) scale.y)) {

            throw new Exception(format!"Failed to load `%s` at size %s, error no. %s"(filename, size, error));

        }

    }

    ~this() @trusted {

        // Ignore if the resources used by the class have been borrowed
        if (!isOwner) return;

        FT_Done_Face(face);

    }

    long glyphCount() const {

        return face.num_glyphs;

    }

    /// Get pen position for the given cursor position.
    Vector2 penPosition() const {

        return Vector2(0, face.size.metrics.ascender) / 64;

    }

    /// Line height.
    int lineHeight() const {

        // +1 is an error margin
        return cast(int) (face.size.metrics.height / 64) + 1;

    }

    /// Get advance vector for the given glyph
    Vector2 advance(dchar glyph) const @trusted {

        // Sadly, there is no way to make FreeType operate correctly in `const` environment.

        // Load the glyph
        if (auto error = FT_Load_Char(cast(FT_FaceRec*) face, glyph, FT_LOAD_DEFAULT)) {

            return Vector2(0, 0);

        }

        // Advance the cursor position
        // TODO RTL layouts
        return Vector2(face.glyph.advance.tupleof) / 64;

    }

    /// Draw a line of text
    void drawLine(ref Image target, ref Vector2 penPosition, string text, Color tint) const @trusted {

        // TODO Maybe it would be a better idea to draw characters in batch? This could improve Raylib compatibility.

        foreach (dchar glyph; text) {

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

                    // Note: ImageDrawPixel overrides the pixel — alpha blending has to be done by us
                    const oldColor = GetImageColor(target, targetX, targetY);
                    const newColor = ColorAlpha(tint, cast(float) pixel / pixel.max);
                    const color = ColorAlphaBlend(oldColor, newColor, Colors.WHITE);

                    ImageDrawPixel(&target, targetX, targetY, color);

                }

            }

            // Advance pen positon
            penPosition += Vector2(face.glyph.advance.tupleof) / 64;

        }

    }

}

// RaylibTypeface would be here... If I made one!
// Turns out, drawing text to existing images is incredibly painful in Raylib. `ImageDrawText` temporarily allocates a
// new image just to draw text to it and then copy to the one we're interested in. That's a TON of overhead to do just
// that.

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
