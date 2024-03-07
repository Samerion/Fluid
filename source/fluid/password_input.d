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

    /// Get the radius of the circles
    protected float radius() const {

        auto typeface = style.getTypeface;

        // Use the "X" character as reference
        return typeface.advance('X').x / 2f;

    }

    /// Get the advance width of the circles.
    protected float advance() const {

        auto typeface = style.getTypeface;

        return typeface.advance('X').x * 1.2;

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

        import std.utf : decode;

        size_t index;
        size_t number;

        while (index < value.length) {

            // Stop if found the character
            if (needle.x < number * advance + radius) break;

            // Locate the next character
            decode(value, index);
            number++;

        }

        return number;

    }

    protected override Vector2 caretPositionImpl(float availableWidth, bool preferNextLine) {

        import std.utf : count;
        import fluid.typeface : TextRuler;

        return Vector2(
            advance * count(valueBeforeCaret),
            super.caretPositionImpl(availableWidth, preferNextLine).y,
        );

    }

    /// Draw selection, if applicable.
    protected override void drawSelection(Rectangle inner) {

        import std.utf : count;
        import std.range : enumerate;
        import std.algorithm : min, max;

        // Ignore if selection is empty
        if (selectionStart == selectionEnd) return;

        const typeface = style.getTypeface;

        const low = min(selectionStart, selectionEnd);
        const high = max(selectionStart, selectionEnd);

        const start = advance * count(value[0 .. low]);
        const size = advance * count(value[low .. high]);

        const rect = Rectangle(
            (inner.start + Vector2(start, 0)).tupleof,
            size, typeface.lineHeight,
        );

        io.drawRectangle(rect, style.selectionBackgroundColor);

    }

}
