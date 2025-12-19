module fluid.text.typeface;

import std.range;
import std.string;
import std.algorithm;

import fluid.utils;
import fluid.types;
import fluid.text.rope;
import fluid.text.ruler;

public import fluid.text.util : keepWords, breakWords;

@safe:

/// Low-level interface for drawing text. Represents a single typeface.
///
/// Unlike the rest of Fluid, Typeface uses screen-space dots directly, instead of fixed-size pixels. Consequently, DPI
/// must be specified manually.
///
/// See: [fluid.text.Text] for an interface on a higher level.
interface Typeface {

    public import fluid.text.util : defaultWordChunks;
    public import fluid.text.ruler : eachWord;
    deprecated("Use Rope.byLine instead. lineSplitter will be removed in 0.9.0") {
        public import fluid.text.util : lineSplitter, lineSplitterIndex;
    }

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
        foreach (line; Rope(text).byLine) {

            ruler.startLine();

            // Split on words; do nothing in particular, just run the measurements
            foreach (word, penPosition; eachWord!chunkWords(ruler, line, wrap)) { }

        }

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
