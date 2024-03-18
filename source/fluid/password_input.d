module fluid.password_input;

import fluid.utils;
import fluid.backend;
import fluid.text_input;


@safe:


/// A password input box.
alias passwordInput = simpleConstructor!PasswordInput;

/// ditto
class PasswordInput : TextInput {

    mixin enableInputActions;

    protected {

        /// Character circle radius.
        float radius;

        /// Distance between the start positions of each character.
        float advance;

    }

    /// Create a password input.
    /// Params:
    ///     placeholder = Placeholder text for the field.
    ///     submitted   = Callback for when the field is submitted.
    this(string placeholder = "", void delegate() @trusted submitted = null) {

        super(placeholder, submitted);

    }

    /// PasswordInput does not support multiline.
    override bool multiline() const {

        return false;

    }

    protected override void drawContents(Rectangle inner, Rectangle innerScrolled) {

        auto typeface = pickStyle.getTypeface;

        // Empty, draw the placeholder using regular input
        if (isEmpty) return super.drawContents(inner, innerScrolled);

        // Draw selection
        drawSelection(innerScrolled);

        auto cursor = start(innerScrolled) + Vector2(radius, typeface.lineHeight / 2f);

        // Draw a circle for each character
        foreach (_; value) {

            io.drawCircle(cursor, radius, style.textColor);

            cursor.x += advance;

        }

        // Draw the caret
        drawCaret(innerScrolled);

    }

    override size_t nearestCharacter(Vector2 needle) const {

        import std.utf : byDchar;

        size_t number;

        foreach (ch; value[].byDchar) {

            // Stop if found the character
            if (needle.x < number * advance + radius) break;

            number++;

        }

        return number;

    }

    protected override Vector2 caretPositionImpl(float availableWidth, bool preferNextLine) {

        return Vector2(
            advance * valueBeforeCaret.countCharacters,
            super.caretPositionImpl(availableWidth, preferNextLine).y,
        );

    }

    /// Draw selection, if applicable.
    protected override void drawSelection(Rectangle inner) {

        import std.range : enumerate;
        import std.algorithm : min, max;

        // Ignore if selection is empty
        if (selectionStart == selectionEnd) return;

        const typeface = style.getTypeface;

        const low = min(selectionStart, selectionEnd);
        const high = max(selectionStart, selectionEnd);

        const start = advance * value[0 .. low].countCharacters;
        const size = advance * value[low .. high].countCharacters;

        const rect = Rectangle(
            (inner.start + Vector2(start, 0)).tupleof,
            size, typeface.lineHeight,
        );

        io.drawRectangle(rect, style.selectionBackgroundColor);

    }

    protected override void reloadStyles() {

        super.reloadStyles();

        // Use the "X" character as reference
        auto typeface = style.getTypeface;
        auto x = typeface.advance('X').x;

        radius = x / 2f;
        advance = x * 1.2;

    }

}
