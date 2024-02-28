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

    protected override void drawImpl(Rectangle outer, Rectangle inner) @trusted {

        import std.utf : count;
        import std.algorithm : min, max;

        auto style = pickStyle();
        auto typeface = style.getTypeface;

        // Use the "X" character as a reference
        const reference = typeface.advance('X');
        const advance = reference.x * 1.2;
        const radius = reference.x / 2f;
        const width = advance * count(value);
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

        const caretOffset = min(width, inner.w);

        // Draw the caret
        drawCaret(inner, caretOffset);

    }

}
