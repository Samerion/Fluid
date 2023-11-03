module glui.typeface;

import raylib;
import bindbc.freetype;

import std.string;


@safe:


/// Represents a single typeface in Glui.
interface Typeface {

    /// List glyphs  in the typeface.
    long glyphCount() const;

    /// Get pen position for the given cursor position.
    Vector2 penPosition(Vector2 cursorPosition) const;

    /// Get advance vector for the given glyph
    Vector2 advance(dchar glyph) const;

    /// Draw a single glyph.
    void drawGlyph(ref Image target, Vector2 penPosition, dchar glyph, Color tint) const;

    /// Measure space the given text would span.
    final Rectangle measureText(Rectangle availableSpace, string text, Color tint, bool wrap = true) const {

        assert(false);

    }

    /// Draw text at given position.
    final void draw(ref Image target, Vector2 position, string text, Color tint, bool wrap = true) const {

        assert(false);

    }

}

/// Represents a freetype2-powered typeface.
class FreetypeTypeface : Typeface {

    /// Underlying face.
    public FT_Face face;

    /// If true, this typeface has been loaded using this class, making the class responsible for freeing the font.
    protected bool isOwner;

    /// Use an existing freetype2 font.
    this(FT_Face face) {

        this.face = face;
        this.isOwner = false;

    }

    /// Load a font from a file.
    this(string filename) @trusted {

        this.isOwner = true;

        // TODO proper exceptions
        if (auto error = FT_New_Face(freetype, filename.toStringz, 0, &this.face)) {

            throw new Exception(format!"Failed to load `%s`, error no. %s"(filename, error));

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

    void draw(Vector2 position, string text) const {

        assert(false);

    }

}

// RaylibTypeface would be here... If I made one!
// Turns out, drawing text to existing images is incredibly painful in Raylib. `ImageDrawText` temporarily allocates a
// new image just to draw text to it and then copy to the one we're interested in. That's a TON of overhead to do just
// that.

shared static this() @system{

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
