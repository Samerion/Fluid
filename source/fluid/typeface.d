module fluid.typeface;

import bindbc.freetype;

import std.range;
import std.traits;
import std.string;
import std.algorithm;

import fluid.utils;
import fluid.backend;


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


/// Low-level interface for drawing text. Represents a single typeface.
///
/// Unlike the rest of Fluid, Typeface doesn't define pixels as 1/96th of an inch. DPI must also be specified manually.
///
/// See: [fluid.text.Text] for an interface on a higher level.
interface Typeface {

    /// List glyphs  in the typeface.
    long glyphCount() const;

    /// Get initial pen position.
    Vector2 penPosition() const;

    /// Get line height.
    int lineHeight() const;

    /// Get advance vector for the given glyph. Uses dots, not pixels, as the unit.
    Vector2 advance(dchar glyph) const;

    /// Set font scale. This should be called at least once before drawing.
    ///
    /// Font renderer should cache this and not change the scale unless updated.
    ///
    /// Params:
    ///     scale = Horizontal and vertical DPI value, for example (96, 96)
    Vector2 dpi(Vector2 scale);

    /// Get curently set DPI.
    Vector2 dpi() const;

    /// Draw a line of text.
    /// Note: This API is unstable and might change over time.
    void drawLine(ref Image target, ref Vector2 penPosition, const(char)[] text, Color tint) const;

    /// Instances of Typeface have to be comparable in a memory-safe manner.
    bool opEquals(const Object object) @safe const;

    /// Get the default Fluid typeface.
    static defaultTypeface() => FreetypeTypeface.defaultTypeface;

    /// Default word splitter used by measure/draw.
    static defaultWordChunks(Range)(Range range) {

        import std.uni;
        import std.conv;

        /// Pick the group the character belongs to.
        static bool pickGroup(dchar a) {

            return a.isAlphaNum || a.isPunctuation;

        }

        return range
            .splitWhen!((a, b) => pickGroup(a) != pickGroup(b) && !b.isWhite)
            .map!(a => a.to!(const(char)[]))
            .cache;
        // TODO string allocation could probably be avoided

    }

    /// Updated version of std lineSplitter that includes trailing empty lines.
    ///
    /// `lineSplitterIndex` will produce a tuple with the index into the original text as the first element.
    static lineSplitter(C)(C[] text) {

        import std.utf : UTFException;
        import std.uni : lineSep, paraSep;

        try {

            const hasEmptyLine = text.endsWith('\r', '\n', '\v', '\f', "\r\n", lineSep, paraSep, '\u0085') != 0;
            auto split = .lineSplitter(text);

            // Include the empty line if present
            return hasEmptyLine.choose(
                split.chain(only(typeof(text).init)),
                split,
            );

        }

        // Provide more helpful messages if endsWith fails
        catch (UTFException exc) {

            exc.msg = format!"Invalid UTF string: `%s` %s"(text, text.representation);
            throw exc;

        }

    }

    /// ditto
    static lineSplitterIndex(C)(C[] text) {

        import std.typecons : tuple;

        return Typeface.lineSplitter(text)

            // Insert the index
            .map!(a => tuple(
                cast(size_t) a.ptr - cast(size_t) text.ptr,
                a,
            ));

    }

    /// Measure space the given text would span. Uses dots as the unit.
    ///
    /// If `availableSpace` is specified, assumes text wrapping. Text wrapping is only performed on whitespace
    /// characters.
    ///
    /// Params:
    ///     chunkWords = Algorithm to use to break words when wrapping text; separators must be preserved as separate
    ///         words.
    ///     availableSpace = Amount of available space the text can take up (dots), used to wrap text.
    ///     text = Text to measure.
    ///     wrap = Toggle text wrapping. Defaults to on, unless using the single argument overload.
    ///
    /// Returns:
    ///     Vector2 representing the text size, if `TextRuler` is not specified as an argument.
    final Vector2 measure(alias chunkWords = defaultWordChunks, String)
        (Vector2 availableSpace, String text, bool wrap = true) const
    if (isSomeString!String)
    do {

        auto ruler = TextRuler(this, wrap ? availableSpace.x : float.nan);

        measure!chunkWords(ruler, text, wrap);

        return ruler.textSize;

    }

    /// ditto
    final Vector2 measure(String)(String text) const
    if (isSomeString!String)
    do {

        // No wrap, only explicit in-text line breaks
        auto ruler = TextRuler(this);

        measure(ruler, text, false);

        return ruler.textSize;

    }

    /// ditto
    static void measure(alias chunkWords = defaultWordChunks, String)
        (ref TextRuler ruler, String text, bool wrap = true)
    if (isSomeString!String)
    do {

        // TODO don't fail on decoding errors
        // TODO RTL layouts
        // TODO vertical text

        // Split on lines
        foreach (line; lineSplitter(text)) {

            ruler.startLine();

            // Split on words; do nothing in particular, just run the measurements
            foreach (word, penPosition; eachWord!chunkWords(ruler, line, wrap)) { }

        }

    }

    /// Helper function
    static auto eachWord(alias chunkWords = defaultWordChunks, String)
        (ref TextRuler ruler, String text, bool wrap = true)
    do {

        struct Helper {

            alias ElementType = CommonType!(String, typeof(chunkWords(text).front));

            // I'd use `choose` but it's currently broken
            int opApply(int delegate(ElementType, Vector2) @safe yield) {

                // Text wrapping on
                if (wrap) {

                    auto range = chunkWords(text);

                    // Empty line, yield an empty word
                    if (range.empty) {

                        const penPosition = ruler.addWord(String.init);
                        if (const ret = yield(String.init, penPosition)) return ret;

                    }

                    // Split each word
                    else foreach (word; chunkWords(text)) {

                        const penPosition = ruler.addWord(word);
                        if (const ret = yield(word, penPosition)) return ret;

                    }

                    return 0;

                }

                // Text wrapping off
                else {

                    const penPosition = ruler.addWord(text);
                    return yield(text, penPosition);

                }

            }

        }

        return Helper();

    }

    /// Draw text within the given rectangle in the image.
    final void draw(alias chunkWords = defaultWordChunks, String)
        (ref Image image, Rectangle rectangle, String text, Color tint, bool wrap = true)
    const {

        auto ruler = TextRuler(this, rectangle.w);

        // TODO decoding errors

        // Split on lines
        foreach (line; this.lineSplitter(text)) {

            ruler.startLine();

            // Split on words
            foreach (word, penPosition; eachWord!chunkWords(ruler, line, wrap)) {

                auto wordPenPosition = rectangle.start + penPosition;

                drawLine(image, wordPenPosition, word, tint);

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

    /// Index of the word within the line.
    size_t wordLineIndex;

    this(const Typeface typeface, float lineWidth = float.nan) {

        this.typeface = typeface;
        this.lineWidth = lineWidth;
        this.penPosition = typeface.penPosition;

    }

    /// Get the caret as a 0 width rectangle.
    Rectangle caret() const {

        return caret(penPosition);

    }

    /// Get the caret as a 0 width rectangle for the given pen position.
    Rectangle caret(Vector2 penPosition) const {

        const start = penPosition - Vector2(0, typeface.penPosition.y);

        return Rectangle(
            start.tupleof,
            0, typeface.lineHeight,
        );

    }

    /// Begin a new line.
    void startLine() {

        const lineHeight = typeface.lineHeight;

        if (textSize != Vector2.init) {

            // Move the pen to the next line
            penPosition.x = typeface.penPosition.x;
            penPosition.y += lineHeight;

        }

        // Allocate space for the line
        textSize.y += lineHeight;
        wordLineIndex = 0;

    }

    /// Add the given word to the text. The text must be a single line.
    /// Returns: Pen position for the word. It might differ from the original penPosition, because the word may be
    ///     moved onto the next line.
    Vector2 addWord(String)(String word) {

        const maxWordWidth = lineWidth - penPosition.x;

        float wordSpan = 0;

        // Measure each glyph
        foreach (dchar glyph; word) {

            wordSpan += typeface.advance(glyph).x;

        }

        // Exceeded line width
        // Automatically false if lineWidth is NaN
        if (maxWordWidth < wordSpan && wordLineIndex != 0) {

            // Start a new line
            startLine();

        }

        const wordPosition = penPosition;

        // Increment word index
        wordLineIndex++;

        // Update pen position
        penPosition.x += wordSpan;

        // Allocate space
        if (penPosition.x > textSize.x) {

            textSize.x = penPosition.x;

            // Limit space to not exceed maximum width (false if NaN)
            if (textSize.x > lineWidth) {

                textSize.x = lineWidth;

            }

        }

        return wordPosition;

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

    private {

        /// If true, this typeface has been loaded using this class, making the class responsible for freeing the font.
        bool _isOwner;

        /// Font size loaded (points).
        int _size;

        /// Current DPI set for the typeface.
        int _dpiX, _dpiY;

    }

    static FreetypeTypeface defaultTypeface;

    static this() @trusted {

        // Set the default typeface
        FreetypeTypeface.defaultTypeface = new FreetypeTypeface(14);

    }

    /// Load the default typeface
    this(int size) @trusted {

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
    this(FT_Face face, int size) {

        this.face = face;
        this._size = size;

    }

    /// Load a font from a file.
    /// Params:
    ///     backend  = I/O Fluid backend, used to adjust the scale of the font.
    ///     filename = Filename of the font file.
    ///     size     = Size of the font to load (in points).
    this(string filename, int size) @trusted {

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

    bool isOwner() const => _isOwner;
    bool isOwner(bool value) @system => _isOwner = value;

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

        // Load size
        if (auto error = FT_Set_Char_Size(face, 0, _size*64, dpiX, dpiY)) {

            throw new Exception(
                format!"Failed to load font at size %s at DPI %sx%s, error no. %s"(_size, dpiX, dpiY, error)
            );

        }

        return dpi;

    }

    /// Get advance vector for the given glyph
    Vector2 advance(dchar glyph) const @trusted {

        assert(_dpiX && _dpiY, "Font DPI hasn't been set");

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
    void drawLine(ref Image target, ref Vector2 penPosition, const(char)[] text, Color tint) const @trusted {

        assert(_dpiX && _dpiY, "Font DPI hasn't been set");

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
                    const oldColor = target.get(targetX, targetY);
                    const newColor = tint.setAlpha(cast(float) pixel / pixel.max);
                    const color = alphaBlend(oldColor, newColor);

                    target.get(targetX, targetY) = color;

                }

            }

            // Advance pen positon
            penPosition += Vector2(face.glyph.advance.tupleof) / 64;

        }

    }

}

/// Font rendering via Raylib. Discouraged, potentially slow, and not HiDPI-compatible. Use `FreetypeTypeface` instead.
version (Have_raylib_d)
class RaylibTypeface : Typeface {

    import raylib;

    public {

        /// Character spacing, as a fraction of the font size.
        float spacing = 0.1;

        /// Line height relative to font height.
        float relativeLineHeight = 1.4;

        /// Scale to apply for the typeface.
        float scale = 1.0;

    }

    private {

        /// Underlying Raylib font.
        Font _font;

        /// If true, this is the default font, and has to be available ahead of time.
        ///
        /// If the typeface is requested before Raylib is loaded (...and it is...), the default font won't be available,
        /// so we must use late loading.
        bool _isDefault;

        /// If true, this typeface has been loaded using this class, making the class responsible for freeing the font.
        bool _isOwner;

    }

    /// Object holding the default typeface.
    static RaylibTypeface defaultTypeface() @trusted {

        static RaylibTypeface typeface;

        // Load the typeface
        if (!typeface) {
            typeface = new RaylibTypeface(GetFontDefault);
            typeface._isDefault = true;
            typeface.scale = 2.0;
        }

        return typeface;

    }

    /// Load a Raylib font.
    this(Font font) {

        this._font = font;

    }

    /// Load a Raylib font from file.
    deprecated("Raylib font rendering is inefficient and lacks scaling. Use FreetypeTypeface instead")
    this(string filename, int size) @trusted {

        this._font = LoadFontEx(filename.toStringz, size, null, 0);
        this.isOwner = true;

    }

    ~this() @trusted {

        if (isOwner) {

            UnloadFont(_font);

        }

    }

    /// Instances of Typeface have to be comparable in a memory-safe manner.
    override bool opEquals(const Object object) @safe const {

        return this is object;

    }

    Font font() @trusted {

        if (_isDefault)
            return _font = GetFontDefault;
        else
            return _font;

    }

    const(Font) font() const @trusted {

        if (_isDefault)
            return GetFontDefault;
        else
            return _font;

    }

    bool isOwner() const => _isOwner;
    bool isOwner(bool value) @system => _isOwner = value;

    /// List glyphs  in the typeface.
    long glyphCount() const {

        return font.glyphCount;

    }

    /// Get initial pen position.
    Vector2 penPosition() const {

        return Vector2(0, 0);

    }

    /// Get font height in pixels.
    int fontHeight() const {

        return cast(int) (font.baseSize * scale);

    }

    /// Get line height in pixels.
    int lineHeight() const {

        return cast(int) (fontHeight * relativeLineHeight);

    }

    /// Changing DPI at runtime is not supported for Raylib typefaces.
    Vector2 dpi(Vector2 dpi) {

        // Not supported for Raylib typefaces.
        return Vector2(96, 96);

    }

    Vector2 dpi() const {

        return Vector2(96, 96);

    }

    /// Get advance vector for the given glyph.
    Vector2 advance(dchar codepoint) const @trusted {

        const glyph = GetGlyphInfo(cast() font, codepoint);
        const spacing = fontHeight * this.spacing;
        const baseAdvanceX = glyph.advanceX
            ? glyph.advanceX
            : glyph.offsetX + glyph.image.width;
        const advanceX = baseAdvanceX * scale;

        return Vector2(advanceX + spacing, 0);

    }

    /// Draw a line of text
    /// Note: This API is unstable and might change over time.
    void drawLine(ref .Image target, ref Vector2 penPosition, const(char)[] text, Color tint) const @trusted {

        // Note: `DrawTextEx` doesn't scale `spacing`, but `ImageDrawTextEx` DOES. The image is first drawn at base size
        //       and *then* scaled.
        const spacing = font.baseSize * this.spacing;

        // We trust Raylib will not mutate the font
        // Raylib is single-threaded, so it shouldn't cause much harm anyway...
        auto font = cast() this.font;

        // Make a Raylib-compatible wrapper for image data
        auto result = target.toRaylib;

        ImageDrawTextEx(&result, font, text.toStringz, penPosition, fontHeight, spacing, tint);

    }

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
