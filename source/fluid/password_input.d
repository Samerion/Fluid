module fluid.password_input;

import fluid.utils;
import fluid.style;
import fluid.backend;
import fluid.text_input;

import fluid.io.canvas;

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

    private {

        char[][] _bufferHistory;

    }

    /// Create a password input.
    /// Params:
    ///     placeholder = Placeholder text for the field.
    ///     submitted   = Callback for when the field is submitted.
    this(string placeholder = "", void delegate() @trusted submitted = null) {

        super(placeholder, submitted);
        this.contentLabel = new LocalContentLabel;

    }

    static class LocalContentLabel : ContentLabel {

        override void resizeImpl(Vector2) {

            use(canvasIO);

            const x = getAdvanceX(io, canvasIO, style);
            const radius = x / 2f;
            const advance = x * 1.2;
            minSize = Vector2(
                advance * value.countCharacters,
                radius * 2,
            );

        }

    }

    /// PasswordInput does not support multiline.
    override bool multiline() const {

        return false;

    }

    /// Delete all textual data created by the password box. All text typed inside the box will be overwritten, except
    /// for any copies, if they were made. Clears the box.
    ///
    /// The password box keeps a buffer of all text that has ever been written to it, in order to store and display its
    /// content. The security implication is that, even if the password is no longer needed, it will remain in program
    /// memory, exposing it as a possible target for attackers, in case [memory corruption vulnerabilities][1] are
    /// found. Even if collected by the garbage collector, the value will remain untouched until the same spot in memory
    /// is reused, so in order to increase the security of a program, passwords should thus be *shredded* after usage,
    /// explicitly overwriting their contents.
    ///
    /// Do note that shredding is never performed automatically — this function has to be called explicitly.
    /// Furthermore, text provided through different means than explicit input or `push(Rope)` will not be cleared.
    ///
    /// [1]: https://en.wikipedia.org/wiki/Memory_safety
    void shred() {

        // Go through each buffer
        foreach (buffer; _bufferHistory) {

            // Clear it
            buffer[] = char.init;

        }

        // Clear the input and buffer history
        clear();
        _bufferHistory = [buffer];

        // Clear undo stack
        clearHistory();

    }

    protected override void resizeImpl(Vector2 space) {

        use(canvasIO);

        // Use the "X" character as reference
        const x = getAdvanceX(io, canvasIO, style);

        radius = x / 2f;
        advance = x * 1.2;

        super.resizeImpl(space);

    }

    protected override void drawContents(Rectangle inner, Rectangle innerScrolled) {

        // Empty, draw the placeholder using regular input
        if (isEmpty) return super.drawContents(inner, innerScrolled);

        // Draw selection
        drawSelection(innerScrolled);

        auto cursor = start(innerScrolled) + Vector2(radius, lineHeight / 2f);

        // Draw a circle for each character
        if (canvasIO) {
            foreach (_; value) {
                canvasIO.drawCircle(cursor, radius, style.textColor);
                cursor.x += advance;
            }
        }
        else {
            foreach (_; value) {
                io.drawCircle(cursor, radius, style.textColor);
                cursor.x += advance;
            }
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

        const low = min(selectionStart, selectionEnd);
        const high = max(selectionStart, selectionEnd);

        const start = advance * value[0 .. low].countCharacters;
        const size = advance * value[low .. high].countCharacters;

        const rect = Rectangle(
            (inner.start + Vector2(start, 0)).tupleof,
            size, lineHeight,
        );

        if (canvasIO) {
            canvasIO.drawRectangle(rect, style.selectionBackgroundColor);
        }
        else {
            io.drawRectangle(rect, style.selectionBackgroundColor);
        }

    }

    /// Get the X advance of letter "X."
    protected static float getAdvanceX(FluidBackend io, CanvasIO canvasIO, Style style) {

        float scale;

        if (canvasIO) {
            style.setDPI(canvasIO.dpi);
            scale = canvasIO.toDots(Vector2(1, 0)).x;
        }
        else {
            style.setDPI(io.dpi);
            scale = io.hidpiScale.x;
        }

        return style.getTypeface.advance('X').x / scale;

    }

    /// Request a new or larger buffer.
    ///
    /// `PasswordInput` keeps track of all the buffers that have been used since its creation in order to make it
    /// possible to `shred` the contents once they're unnecessary.
    ///
    /// Params:
    ///     minimumSize = Minimum size to allocate for the buffer.
    protected override void newBuffer(size_t minimumSize = 64) {

        // Create the buffer
        super.newBuffer(minimumSize);

        // Remember the buffer
        _bufferHistory ~= buffer;

    }

}

///
unittest {

    // PasswordInput lets you ask the user for passwords
    auto node = passwordInput();

    // Retrieve the password with `value`
    auto userPassword = node.value;

    // Destroy the passwords once you're done to secure them against attacks
    // (Careful: This will invalidate `userPassword` we got earlier)
    node.shred();

}
