/// The purpose of this module is to provide a low level API for keeping track of pen position and measuring distance 
/// between two points in text.
module fluid.text.ruler;

import fluid.backend;
import fluid.text.typeface;

@safe:

/// Low level interface for measuring text.
struct TextRuler {

    /// Typeface to use for the text.
    Typeface typeface;

    /// Maximum width for a single line in display-specific dots. If `NaN`, no word breaking is performed.
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

    bool opEquals(const TextRuler other) const {

        import std.math : isNaN;

        const sameLineWidth = lineWidth == other.lineWidth
            || (isNaN(lineWidth) && isNaN(other.lineWidth));

        return sameLineWidth
            && typeface      is other.typeface
            && penPosition   == other.penPosition
            && textSize      == other.textSize
            && wordLineIndex == other.wordLineIndex;

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
