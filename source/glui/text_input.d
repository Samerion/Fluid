///
module glui.text_input;

import raylib;

import glui.node;
import glui.input;
import glui.style;
import glui.utils;

alias textInput = simpleConstructor!GluiTextInput;

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
        "style", q{ Style.init },
        "focusStyle", q{ style },
        "emptyStyle", q{ style },
    );

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

    override void resizeImpl(Vector2 arg) {

        import std.algorithm : max;

        // Set the size
        minSize = size;

        // Single line
        if (!multiline) {

            // Set height to at least the font size
            minSize.y = max(minSize.y, style.fontSize);

        }

    }

    override void drawImpl(Rectangle rect) const {

        auto style = pickStyle(rect);

        // Fill the background
        style.drawBackground(rect);

        // Draw the text
        style.drawText(rect, value ? value : placeholder);

    }

    // TODO: style inheritance needs to be implemented first
    override const(Style) pickStyle(Rectangle) const {

        return style;

    }

}
