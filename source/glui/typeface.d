module glui.typeface;

import raylib;
import bindbc.freetype;

import std.range;
import std.traits;
import std.string;
import std.algorithm;

import glui.utils;


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

    /// Default word splitter used by measure/draw.
    final defaultWordChunks(Range)(Range range) const {

        import std.uni;

        /// Pick the group the character belongs to.
        static bool pickGroup(dchar a) {

            return a.isAlphaNum || a.isPunctuation;

        }

        return range
            .splitWhen!((a, b) => pickGroup(a) != pickGroup(b) && !b.isWhite)
            .map!"text(a)"
            .cache;
        // TODO string allocation could probably be avoided

    }

    /// Measure space the given text would span.
    ///
    /// If `availableSpace` is specified, assumes text wrapping. Text wrapping is only performed on whitespace
    /// characters.
    ///
    /// Params:
    ///     chunkWords = Algorithm to use to break words when wrapping text; separators must be preserved.
    ///     availableSpace = Amount of available space the text can take up (pixels), used for text wrapping.
    ///     text = Text to measure.
    ///     wrap = Toggle text wrapping.
    final Vector2 measure(alias chunkWords = defaultWordChunks, String)
        (Vector2 availableSpace, String text, bool wrap = true) const
    if (isSomeString!String)
    do {

        // Wrapping off
        if (!wrap) return measure(text);

        auto ruler = TextRuler(this, availableSpace.x);

        // TODO don't fail on decoding errors
        // TODO RTL layouts
        // TODO vertical text
        // TODO lineSplitter removes the last line feed if present, which is unwanted behavior

        // Split on lines
        foreach (line; text.lineSplitter) {

            ruler.startLine();

            // Split on words
            foreach (word; chunkWords(line)) {

                ruler.addWord(word);

            }

        }

        return ruler.textSize;

    }

    /// ditto
    final Vector2 measure(String)(String text) const
    if (isSomeString!String)
    do {

        // No wrap, only explicit in-text line breaks

        auto ruler = TextRuler(this);

        // TODO don't fail on decoding errors

        // Split on lines
        foreach (line; text.lineSplitter) {

            ruler.startLine();
            ruler.addWord(line);

        }

        return ruler.textSize;

    }

    /// Draw text within the given rectangle in the image.
    final void draw(alias chunkWords = defaultWordChunks, String)
        (ref Image image, Rectangle rectangle, String text, Color tint, bool wrap = true)
    const {

        auto ruler = TextRuler(this, rectangle.w);

        // TODO decoding errors

        // Text wrapping on
        if (wrap) {

            // Split on lines
            foreach (line; text.lineSplitter) {

                ruler.startLine();

                // Split on words
                foreach (word; chunkWords(line)) {

                    auto penPosition = rectangle.start + ruler.addWord(word);

                    drawLine(image, penPosition, word, tint);

                }

            }

        }

        // Text wrapping off
        else {

            // Split on lines
            foreach (line; text.lineSplitter) {

                ruler.startLine();

                auto penPosition = rectangle.start + ruler.addWord(line);

                drawLine(image, penPosition, line, tint);

            }

        }

    }

}

/// Low level interface for measuring text.
struct TextRuler {

    /// Typeface to use for the text.
    const Typeface typeface;

    /// Maximum width for a single line. If `NaN`, no word breaking is performed.
    float lineWidth;

    /// Current pen position.
    Vector2 penPosition;

    /// Total size of the text.
    Vector2 textSize;

    this(const Typeface typeface, float lineWidth = float.init) {

        this.typeface = typeface;
        this.lineWidth = lineWidth;

        penPosition = typeface.penPosition - typeface.lineHeight;

    }

    /// Begin a new line.
    void startLine() {

        const lineHeight = typeface.lineHeight;

        // Move the pen to the next line
        penPosition.x = 0;
        penPosition.y += lineHeight;
        textSize.y += lineHeight;

    }

    /// Add the given word to the text. The text must be single line.
    /// Returns: Pen position for the word.
    Vector2 addWord(String)(String word) {

        const maxWordWidth = lineWidth - penPosition.x;

        float wordSpan = 0;

        // Measure each glyph
        foreach (dchar glyph; word) {

            wordSpan += typeface.advance(glyph).x;

        }

        // Exceeded line width
        // Automatically false if lineWidth is NaN
        if (maxWordWidth < wordSpan && wordSpan < lineWidth) {

            // Start a new line
            startLine();

        }

        const wordPosition = penPosition;

        // Update pen position
        penPosition.x += wordSpan;

        // Allocate space
        if (penPosition.x > textSize.x) textSize.x = penPosition.x;

        return wordPosition;

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

    /// Get initial pen position.
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

                    // Don't draw pixels out of bounds
                    if (targetX >= target.width || targetY >= target.height) continue;

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
