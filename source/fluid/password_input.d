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

        float width;

    }

    /// Create a password input.
    /// Params:
    ///     placeholder = Placeholder text for the field.
    ///     submitted   = Callback for when the field is submitted.
    this(string placeholder = "", void delegate() @trusted submitted = null) {

        super(placeholder, submitted);

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

        width = advance * count(value);

        super.resizeImpl(space);

    }

    protected override void drawImpl(Rectangle outer, Rectangle inner) {

        import std.algorithm : min, max;

        auto style = pickStyle();
        auto typeface = style.getTypeface;

        // Use the "X" character as a reference
        const scrollOffset = max(0, width - inner.w);

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

    protected override Vector2 caretPositionImpl(Vector2 availableSpace) {

        import fluid.typeface : TextRuler;

        const position = super.caretPositionImpl(availableSpace);

        return Vector2(width, position.y);

    }

}
