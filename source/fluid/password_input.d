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

    private {

        float _caretX;

    }

    /// Create a password input.
    /// Params:
    ///     placeholder = Placeholder text for the field.
    ///     submitted   = Callback for when the field is submitted.
    this(string placeholder = "", void delegate() @trusted submitted = null) {

        super(placeholder, submitted);

    }

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

    protected override void resizeImpl(Vector2 space) {

        import std.utf : count;

        _caretX = advance * count(valueBeforeCaret);

        super.resizeImpl(space);

    }

    protected override void drawImpl(Rectangle outer, Rectangle inner) {

        import std.algorithm : min, max;

        auto style = pickStyle();
        auto typeface = style.getTypeface;

        // Use the "X" character as a reference
        const scrollOffset = max(0, _caretX - inner.w);

        // If empty, draw like a regular textInput
        if (isEmpty) {

            super.drawImpl(outer, inner);
            return;

        }

        // Limit visible area
        auto last = tree.pushScissors(outer);
        scope (exit) tree.popScissors(last);

        // Fill the background
        style.drawBackground(tree.io, outer);

        auto cursor = start(inner) + Vector2(radius - scrollOffset, typeface.lineHeight / 2f);

        // Draw a circle for each character
        foreach (_; value) {

            io.drawCircle(cursor, radius, style.textColor);

            cursor.x += advance;

        }

        // Draw the caret
        drawCaret(inner);

    }

    protected override Vector2 caretPositionImpl(float availableWidth) {

        import fluid.typeface : TextRuler;

        const position = super.caretPositionImpl(availableWidth);

        return Vector2(_caretX, position.y);

    }

}
