///
module glui.text_input;

import raylib;

import glui.node;
import glui.input;
import glui.label;
import glui.style;
import glui.utils;
import glui.scroll;
import glui.structs;

alias textInput = simpleConstructor!GluiTextInput;

/// Raylib: Get pressed char
private extern (C) int GetCharPressed() nothrow @nogc;

@safe:

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

    public {

        /// Size of the field.
        auto size = Vector2(200, 0);

        /// Value of the field.
        string value;

        /// A placeholder text for the field, displayed when the field is empty. Style using `emptyStyle`.
        string placeholder;

        /// TODO. If true, this input accepts multiple lines.
        bool multiline;

    }

    /// Underlying label controlling the content. Needed to properly adjust it to scroll.
    private GluiScrollable!(TextImpl, "true") contentLabel;

    static foreach (index; 0 .. BasicNodeParamLength) {

        /// Create a text input.
        /// Params:
        ///     sup         = Node parameters.
        ///     placeholder = Placeholder text for the field.
        ///     submitted   = Callback for when the field is submitted (enter pressed, ctrl+enter if multiline).
        this(BasicNodeParam!index sup, string placeholder = "", void delegate() @trusted submitted = null) {

            super(sup);
            this.placeholder = placeholder;
            this.submitted = submitted;

            // Create the label
            this.contentLabel = new typeof(contentLabel)(.layout!(1, "fill"));

            with (this.contentLabel) {

                scrollBar.width = 0;
                disableWrap = true;
                ignoreMouse = true;

            }

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

        // Set the label text
        contentLabel.text = (value == "") ? placeholder : value;

        // Inherit main style
        // TODO reuse the hashmap maybe?
        const childTheme = theme.makeTheme!q{

            GluiLabel.styleAdd!q{

                // Those are already included in our theme, we should remove them
                margin = 0;
                padding = 0;
                border = 0;

            };

        };

        // Resize the label
        contentLabel.resize(tree, childTheme, Vector2(0, minSize.y));

    }

    protected override void drawImpl(Rectangle outer, Rectangle inner) @trusted {

        // Note: We're drawing the label in `outer` as the presence of the label is meant to be transparent.

        import std.algorithm : min, max;

        const style = pickStyle();
        const scrollOffset = max(0, contentLabel.scrollMax - inner.w);

        // Fill the background
        style.drawBackground(outer);

        // Copy the style to the label
        contentLabel.activeStyle = style;

        // Set the scroll
        contentLabel.scroll = cast(size_t) scrollOffset;

        // Draw the text
        contentLabel.draw(inner);

        // Ignore the rest if the node isn't focused
        if (!isFocused) return;

        // Add a blinking caret
        if (GetTime % (blinkTime*2) < blinkTime) {

            const lineHeight = style.fontSize * style.lineHeight;
            const margin = style.fontSize / 10f;

            // Put the caret at the start if the placeholder is shown
            const textWidth = value.length
                ? min(contentLabel.scrollMax, inner.w)
                : 0;

            // Get caret position
            const end = Vector2(
                inner.x + textWidth,
                inner.y + inner.height,
            );

            // Draw the caret
            DrawLineV(
                end - Vector2(0, lineHeight - margin),
                end - Vector2(0, margin),
                focusStyle.textColor
            );

        }

    }

    // Do nothing, we take mouse focus while drawing.
    protected override void mouseImpl() @trusted {

        // Update status
        if (IsMouseButtonDown(MouseButton.MOUSE_LEFT_BUTTON)) {

            isFocused = true;

        }

    }

    protected override bool keyboardImpl() @trusted {

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

        // Typed something
        if (input.length || backspace) {

            // Trigger the callback
            if (changed) changed();

            // Update the size of the input
            updateSize();

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
        if (isDisabledInherited) return disabledStyle;

        // Empty text (display placeholder)
        else if (value == "") return emptyStyle;

        // Focused
        else if (isFocused) return focusStyle;

        // Other styles
        else return super.pickStyle();

    }

}

private class TextImpl : GluiLabel {

    mixin DefineStyles!(
        "activeStyle", q{ style }
    );

    this(T...)(T args) {

        super(args);

    }

    // Same as parent, but doesn't draw background
    override void drawImpl(Rectangle outer, Rectangle inner) {

        const style = pickStyle();
        style.drawText(inner, text);

    }

    override const(Style) pickStyle() const {

        return activeStyle;

    }

}
