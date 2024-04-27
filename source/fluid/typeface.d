module fluid.typeface;

import bindbc.freetype;

import std.range;
import std.traits;
import std.string;
import std.algorithm;

import fluid.rope;
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
/// Unlike the rest of Fluid, Typeface uses screen-space dots directly, instead of fixed-size pixels. Consequently, DPI
/// must be specified manually.
///
/// See: [fluid.text.Text] for an interface on a higher level.
interface Typeface {

    /// List glyphs in the typeface.
    long glyphCount() const;

    /// Get initial pen position.
    Vector2 penPosition() const;

    /// Get line height.
    int lineHeight() const;

    /// Width of an indent/tab character, in dots.
    /// `Text` sets `indentWidth` automatically.
    ref inout(int) indentWidth() inout;

    /// Get advance vector for the given glyph. Uses dots, not pixels, as the unit.
    Vector2 advance(dchar glyph);

    /// Set font scale. This should be called at least once before drawing.
    /// `Text` sets DPI automatically.
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
    /// Params:
    ///     target       = Image to draw to.
    ///     penPosition  = Pen position for the beginning of the line. Updated to the pen position at the end of th line.
    ///     text         = Text to draw.
    ///     paletteIndex = If the image has a palette, this is the index to get colors from.
    void drawLine(ref Image target, ref Vector2 penPosition, Rope text, ubyte paletteIndex = 0, const uint size = 0) const;

    /// Instances of Typeface have to be comparable in a memory-safe manner.
    bool opEquals(const Object object) @safe const;

    /// Get the default Fluid typeface.
    static defaultTypeface() => FreetypeTypeface.defaultTypeface;

    /// Default word splitter used by measure/draw.
    alias defaultWordChunks = .breakWords;

    /// Updated version of `std.string.lineSplitter` that includes trailing empty lines.
    ///
    /// `lineSplitterIndex` will produce a tuple with the index into the original text as the first element.
    static lineSplitter(KeepTerminator keepTerm = No.keepTerminator, Range)(Range text)
    if (isSomeChar!(ElementType!Range))
    do {

        import std.utf : UTFException, byDchar;
        import std.uni : lineSep, paraSep;

        const hasEmptyLine = byDchar(text).endsWith('\r', '\n', '\v', '\f', "\r\n", lineSep, paraSep, '\u0085') != 0;
        auto split = .lineSplitter!keepTerm(text);

        // Include the empty line if present
        return hasEmptyLine.choose(
            split.chain(only(typeof(text).init)),
            split,
        );

    }

    /// ditto
    static lineSplitterIndex(Range)(Range text) {

        import std.typecons : tuple;

        auto initialValue = tuple(size_t.init, Range.init, size_t.init);

        return Typeface.lineSplitter!(Yes.keepTerminator)(text)

            // Insert the index, remove the terminator
            // Position [2] is line end index
            .cumulativeFold!((a, line) => tuple(a[2], line.chomp, a[2] + line.length))(initialValue)

            // Remove item [2]
            .map!(a => tuple(a[0], a[1]));

    }

    unittest {

        import std.typecons : tuple;

        auto myLine = "One\nTwo\r\nThree\vStuff\nï\nö";
        auto result = [
            tuple(0, "One"),
            tuple(4, "Two"),
            tuple(9, "Three"),
            tuple(15, "Stuff"),
            tuple(21, "ï"),
            tuple(24, "ö"),
        ];

        assert(lineSplitterIndex(myLine).equal(result));
        assert(lineSplitterIndex(Rope(myLine)).equal(result));

    }

    unittest {

        assert(lineSplitter(Rope("ą")).equal(lineSplitter("ą")));

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
        (Vector2 availableSpace, String text, bool wrap = true)
    do {

        auto ruler = TextRuler(this, wrap ? availableSpace.x : float.nan);

        measure!chunkWords(ruler, text, wrap);

        return ruler.textSize;

    }

    /// ditto
    final Vector2 measure(String)(String text) {

        // No wrap, only explicit in-text line breaks
        auto ruler = TextRuler(this);

        measure(ruler, text, false);

        return ruler.textSize;

    }

    /// ditto
    static void measure(alias chunkWords = defaultWordChunks, String)
        (ref TextRuler ruler, String text, bool wrap = true)
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
        (ref Image image, Rectangle rectangle, String text, ubyte paletteIndex, bool wrap = true)
    const {

        auto ruler = TextRuler(this, rectangle.w);

        // TODO decoding errors

        // Split on lines
        foreach (line; this.lineSplitter(text)) {

            ruler.startLine();

            // Split on words
            foreach (word, penPosition; eachWord!chunkWords(ruler, line, wrap)) {

                auto wordPenPosition = rectangle.start + penPosition;

                drawLine(image, wordPenPosition, word, paletteIndex);

            }

        }

    }

    /// Helper function for typeface implementations, providing a "draw" function for tabs, adjusting the pen position
    /// automatically.
    protected final void drawTab(ref Vector2 penPosition) const {

        penPosition.x += _tabWidth(penPosition.x);

    }

    private final float _tabWidth(float xoffset) const {

        return indentWidth - (xoffset % indentWidth);

    }

}

/// Break words on whitespace and punctuation. Splitter characters stick to the word that precedes them, e.g.
/// `foo!! bar.` is split as `["foo!! ", "bar."]`.
auto breakWords(Range)(Range range) {

    import std.uni : isAlphaNum, isWhite;
    import std.utf : decodeFront;

    /// Pick the group the character belongs to.
    static int pickGroup(dchar a) {

        return a.isAlphaNum ? 0
            : a.isWhite ? 1
            : 2;

    }

    /// Splitter function that splits in any case two
    static bool isSplit(dchar a, dchar b) {

        return !a.isAlphaNum && !b.isWhite && pickGroup(a) != pickGroup(b);

    }

    struct BreakWords {

        Range range;
        Range front = Range.init;

        bool empty() const => front.empty;
        void popFront() {

            dchar lastChar = 0;
            auto originalRange = range.save;

            while (!range.empty) {

                if (lastChar && isSplit(lastChar, range.front)) break;
                lastChar = range.decodeFront;

            }

            front = originalRange[0 .. $ - range.length];

        }

    }

    auto chunks = BreakWords(range);
    chunks.popFront;
    return chunks;

}

unittest {

    const test = "hellö world! 123 hellö123*hello -- hello -- - &&abcde!a!!?!@!@#3";
    const result = [
        "hellö ",
        "world! ",
        "123 ",
        "hellö123*",
        "hello ",
        "-- ",
        "hello ",
        "-- ",
        "- ",
        "&&",
        "abcde!",
        "a!!?!@!@#",
        "3"
    ];

    assert(breakWords(test).equal(result));
    assert(breakWords(Rope(test)).equal(result));

    const test2 = "Аа Бб Вв Гг Дд Ее Ëë Жж Зз Ии "
        ~ "Йй Кк Лл Мм Нн Оо Пп Рр Сс Тт "
        ~ "Уу Фф Хх Цц Чч Шш Щщ Ъъ Ыы Ьь "
        ~ "Ээ Юю Яя ";

    assert(breakWords(test2).equal(breakWords(Rope(test2))));

}

/// Low level interface for measuring text.
struct TextRuler {

    /// Typeface to use for the text.
    Typeface typeface;

    /// Maximum width for a single line. If `NaN`, no word breaking is performed.
    float lineWidth;

    /// Current pen position.
    Vector2 penPosition;

    /// Total size of the text.
    Vector2 textSize;

    /// Index of the word within the line.
    size_t wordLineIndex;

    this(Typeface typeface, float lineWidth = float.nan) {

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

        import std.utf : byDchar;

        const maxWordWidth = lineWidth - penPosition.x;

        float wordSpan = 0;

        // Measure each glyph
        foreach (glyph; byDchar(word)) {

            // Tab aligns to set indent width
            if (glyph == '\t')
                wordSpan += typeface._tabWidth(penPosition.x + wordSpan);

            // Other characters use their regular advance value
            else
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

    protected {

        /// Cache for character sizes.
        Vector2[dchar] advanceCache;

    }

    private {

        /// If true, this typeface has been loaded using this class, making the class responsible for freeing the font.
        bool _isOwner;

        /// Font size loaded (points).
        int _size;

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

    ref inout(int) indentWidth() inout => _indentWidth;
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
    void drawLine(ref Image target, ref Vector2 penPosition, const Rope text, ubyte paletteIndex) const
        => drawLine(target, penPosition, text, paletteIndex, 0);
    void drawLine(ref Image target, ref Vector2 penPosition, const Rope text, ubyte paletteIndex, const uint size) const @trusted {

        assert(_dpiX && _dpiY, "Font DPI hasn't been set");

        FT_Error setSizeError;
        if (size == 0) {
            setSizeError = FT_Set_Char_Size(cast(FT_FaceRec*) face, 0, _size*64, _dpiX, _dpiY);
        } else {
            setSizeError = FT_Set_Char_Size(cast(FT_FaceRec*) face, 0, size*64, _dpiX, _dpiY);
        }
        if (setSizeError) throw new Exception("Text size setting failed.");

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
                        target.set(targetX, targetY, PalettedColor(newAlpha, paletteIndex));

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
