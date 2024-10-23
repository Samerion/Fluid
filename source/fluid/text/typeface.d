module fluid.text.typeface;

import std.range;
import std.traits;
import std.string;
import std.algorithm;

import fluid.utils;
import fluid.backend;
import fluid.text.rope;
import fluid.text.ruler;

@safe:

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
    deprecated("Use setSize instead. dpi(Vector2) will be removed in 0.9.0")
    Vector2 dpi(Vector2 scale);

    /// Get curently set DPI.
    Vector2 dpi() const;

    /// Set the font size. This should be called at least once before drawing.
    /// `Text`, if used, sets this automatically.
    ///
    /// Font renderer should cache this and not change the scale unless updated.
    ///
    /// Params:
    ///     dpi  = Horizontal and vertical DPI value, for example (96, 96).
    ///     size = Size of the font, in pixels.
    void setSize(Vector2 dpi, float size);

    /// Draw a line of text.
    /// Note: This API is unstable and might change over time.
    /// Params:
    ///     target       = Image to draw to.
    ///     penPosition  = Pen position for the beginning of the line. Updated to the pen position at the end of th line.
    ///     text         = Text to draw.
    ///     paletteIndex = If the image has a palette, this is the index to get colors from.
    void drawLine(ref Image target, ref Vector2 penPosition, Rope text, ubyte paletteIndex = 0) const;

    /// Instances of Typeface have to be comparable in a memory-safe manner.
    bool opEquals(const Object object) @safe const;

    /// Get the default Fluid typeface.
    deprecated("Use Style.defaultTypeface instead. Typeface.defaultTypeface will be removed in 0.9.0.")
    static defaultTypeface() {
        import fluid.text.freetype;
        return FreetypeTypeface.defaultTypeface;
    }

    /// Default word splitter used by measure/draw.
    alias defaultWordChunks = .breakWords;

    /// Updated version of `std.string.lineSplitter` that includes trailing empty lines.
    ///
    /// `lineSplitterIndex` will produce a tuple with the index into the original text as the first element.
    static lineSplitter(KeepTerminator keepTerm = No.keepTerminator, Range)(Range text)
    if (isSomeChar!(ElementType!Range))
    do {

        enum dchar lineSep = '\u2028';  // Line separator.
        enum dchar paraSep = '\u2029';  // Paragraph separator.
        enum dchar nelSep  = '\u0085';  // Next line.

        import std.utf : byDchar;

        const hasEmptyLine = byDchar(text).endsWith('\r', '\n', '\v', '\f', "\r\n", lineSep, paraSep, nelSep) != 0;
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
                    else foreach (word; range) {

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

    package final float _tabWidth(float xoffset) const {

        return indentWidth - (xoffset % indentWidth);

    }

}

/// Word breaking implementation that does not break words at all.
/// Params:
///     range = Text to break into words.
auto keepWords(Range)(Range range) {

    return only(range);

}

/// Break words on whitespace and punctuation. Splitter characters stick to the word that precedes them, e.g.
/// `foo!! bar.` is split as `["foo!! ", "bar."]`.
/// Params:
///     range = Text to break into words.
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

        bool empty() const {
            return front.empty;
        }

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
