///
module glui.text_input;

import raylib;

import glui.node;
import glui.input;
import glui.style;
import glui.utils;

alias textInput = simpleConstructor!GluiTextInput;

/// Raylib: Get pressed char
private extern (C) int GetCharPressed() nothrow @nogc;

/// Text input field.
///
/// Styles: $(UL
///     $(LI `style` = Default style for the input.)
///     $(LI `focusStyle` = Style for when the input is focused.)
///     $(LI `emptyStyle` = Style for when the input is empty, i.e. the placeholder is visible. Text should usually be
///         grayed out.)
/// )
class GluiTextInput : GluiInput!GluiNode {

    mixin DefineStyles!(
        "emptyStyle", q{ style },
    );
    mixin ImplHoveredRect;

    /// Time in seconds before the cursor toggles visibility.
    static immutable float blinkTime = 1;

    /// Size of the field.
    auto size = Vector2(200, 0);

    /// Value of the field.
    string value;

    /// A placeholder text for the field, displayed when the field is empty. Style using `emptyStyle`.
    string placeholder;

    /// TODO. If true, this input accepts multiple lines.
    bool multiline;

    static foreach (index; 0 .. BasicNodeParamLength) {

        /// Create a text input.
        /// Params:
        ///     sup         = Node parameters.
        ///     placeholder = Placeholder text for the field.
        ///     submitted   = Callback for when the field is submitted (enter pressed, ctrl+enter if multiline).
        this(BasicNodeParam!index sup, string placeholder = "", void delegate() submitted = null) {

            super(sup);
            this.placeholder = placeholder;
            this.submitted = submitted;

        }

    }

    protected override void resizeImpl(Vector2 area) {

        import std.algorithm : max;

        // Set the size
        minSize = size;

        // Single line
        if (!multiline) {

            // Set height to at least the font size
            minSize.y = max(minSize.y, style.fontSize * style.lineHeight);

        }

    }

    protected override void drawImpl(Rectangle rect) {

        auto style = pickStyle();

        // Fill the background
        style.drawBackground(rect);

        // Draw the text
        const text = (value == "") ? placeholder : value;

        // If the box is focused
        if (isFocused) {

            import std.algorithm : max;

            auto textArea = value == ""
                ? Rectangle()
                : style.measureText(rect, text, false);

            const scrollOffset = max(0, textArea.w - rect.w);

            rect.x -= scrollOffset;

            style.drawText(rect, text, false);

            // Add a blinking caret
            if (GetTime % (blinkTime*2) < blinkTime) {

                const margin = style.fontSize / 10f;
                const lineHeight = style.fontSize * style.lineHeight;
                const end = Vector2(
                    textArea.x + textArea.width + margin,
                    textArea.y + textArea.height,
                );

                // Draw the caret
                DrawLineV(
                    end - Vector2(0, lineHeight - margin),
                    end - Vector2(0, margin),
                    style.textColor
                );

            }

        }

        // Not focused, draw text
        else style.drawText(rect, text, false);

    }

    // Do nothing, we take mouse focus while drawing.
    protected override void mouseImpl() {

        // Update status
        if (IsMouseButtonDown(MouseButton.MOUSE_LEFT_BUTTON)) {

            isFocused = true;

        }

    }

    protected override bool keyboardImpl() {

        import std.uni : isAlpha, isWhite;
        import std.range : back;
        import std.string : chop;

        bool backspace = false;
        string input;

        // Get pressed key
        while (true) {

            // Backspace
            if (value.length && IsKeyPressed(KeyboardKey.KEY_BACKSPACE)) {

                /// If true, delete whole words
                const word = IsKeyDown(KeyboardKey.KEY_LEFT_CONTROL);

                // Remove the last character
                do {

                    const lastChar = value.back;
                    value = value.chop;

                    backspace = true;

                    // Stop instantly if there are no characters left
                    if (value.length == 0) break;


                    // Whitespace, continue deleting
                    if (lastChar.isWhite) continue;

                    // Matching alpha, continue deleting
                    else if (value.back.isAlpha == lastChar.isAlpha) continue;

                    // Break in other cases
                    break;

                }

                // Repeat only if requested to delete whole words
                while (word);

            }

            // Submit
            if (!multiline && IsKeyPressed(KeyboardKey.KEY_ENTER)) {

                isFocused = false;
                if (submitted) submitted();

                return true;

            }


            // Read text
            if (const key = GetCharPressed()) {

                // Append to char arrays
                input ~= cast(dchar) key;

            }

            // Stop if nothing left
            else break;

        }

        value ~= input;

        // Trigger callback
        if ((input.length || backspace) && changed) {

            changed();
            return true;

        }

        // Even if nothing changed, user might have held the key for a while which this function probably wouldn't have
        // caught, so we'd be returning false-positives all the time.
        // The safest way is to just return true always, text input really is complex enough we can assume we did take
        // any input there could be.
        return true;

    }

    override const(Style) pickStyle() const {

        // Disabled
        if (disabled) return disabledStyle;

        // Empty text (display placeholder)
        else if (value == "") return emptyStyle;

        // Other styles
        else return super.pickStyle();

    }

}
