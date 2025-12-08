/// The purpose of this module is to provide a low level API for keeping track of pen position and measuring distance 
/// between two points in text.
module fluid.text.ruler;

import std.traits;

import fluid.types;
import fluid.text.util;
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

    /// If true, the ruler can wrap the next added word onto the next line. False for the first word in the line,
    /// true for any subsequent word. 
    ///
    /// In some cases `TextRuler` can also be in the middle of the word. When this is the case, this will also be set 
    /// to true.
    bool canWrap;

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
            && canWrap       == other.canWrap;

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
        canWrap = false;

    }

    /// Params:
    ///     character = Character to measure.
    ///     offset    = Temporary offset to apply to the pen position. Used to calculate the width of a word.
    /// Returns:
    ///     Width of the given character.
    float characterWidth(dchar character, float offset = 0) {

        // Tab aligns to set indent width
        if (character == '\t')
            return typeface._tabWidth(penPosition.x + offset);

        // Other characters use their regular advance value
        else
            return typeface.advance(character).x;

    }

    /// Add the given word to the text. The text must be a single line.
    /// Returns: 
    ///     Pen position for the start of the word. 
    ///     It might differ from the original penPosition, because the word may be
    ///     moved onto the next line.
    Vector2 addWord(String)(String word) {

        import std.utf : byDchar;

        // Empty word?
        if (word.empty) return penPosition;

        const maxWordWidth = lineWidth - penPosition.x;

        float wordSpan = 0;

        // Measure each glyph
        foreach (glyph; byDchar(word)) {

            wordSpan += characterWidth(glyph, wordSpan);

        }

        // Exceeded line width, start a new line
        // Automatically false if lineWidth is NaN
        if (maxWordWidth < wordSpan && canWrap) {
            startLine();
        }

        const wordPosition = penPosition;

        // Update pen position
        penPosition.x += wordSpan;
        canWrap = true;

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

/// Helper function
auto eachWord(alias chunkWords = defaultWordChunks, String)
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
