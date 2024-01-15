///
module fluid.text_input;

import std.string;

import fluid.node;
import fluid.text;
import fluid.input;
import fluid.label;
import fluid.style;
import fluid.utils;
import fluid.scroll;
import fluid.backend;
import fluid.structs;

alias textInput = simpleConstructor!FluidTextInput;

@safe:

/// Text input field.
///
/// Styles: $(UL
///     $(LI `style` = Default style for the input.)
///     $(LI `focusStyle` = Style for when the input is focused.)
///     $(LI `emptyStyle` = Style for when the input is empty, i.e. the placeholder is visible. Text should usually be
///         grayed out.)
/// )
class FluidTextInput : FluidInput!FluidNode {

    mixin defineStyles!(
        "emptyStyle", q{ style },
    );
    mixin implHoveredRect;
    mixin enableInputActions;

    /// Time in seconds between changes in cursor visibility.
    static immutable float blinkTime = 1;

    public {

        /// Size of the field.
        auto size = Vector2(200, 0);

        /// Value of the field.
        string value;

        /// A placeholder text for the field, displayed when the field is empty. Style using `emptyStyle`.
        string placeholder;

        deprecated("multiline was never supported and will be deleted in 0.7.0") {

            bool multiline() const { return false; }
            bool multiline(bool) { return false; }

        }

    }

    private {

        /// Underlying label controlling the content. Needed to properly adjust it to scroll.
        FluidScrollable!(TextImpl, "true") contentLabel;

    }

    deprecated("Use this(NodeParams, string, void delegate() @safe submitted) instead") {

        static foreach (index; 0 .. BasicNodeParamLength) {

            /// Create a text input.
            /// Params:
            ///     sup         = Node parameters.
            ///     placeholder = Placeholder text for the field.
            ///     submitted   = Callback for when the field is submitted.
            this(BasicNodeParam!index sup, string placeholder = "", void delegate() @trusted submitted = null) {

                super(NodeParams(sup));
                this.placeholder = placeholder;
                this.submitted = submitted;

                // Create the label
                this.contentLabel = new typeof(contentLabel)(NodeParams(.layout!(1, "fill")), "");

                with (this.contentLabel) {

                    // Make the scrollbar invisible
                    scrollBar.disable();
                    scrollBar.width = 0;
                    // Note: We're not hiding the scrollbar, so it may adjust used values to the size of the input

                    disableWrap = true;
                    ignoreMouse = true;

                }

            }

        }

    }

    /// Create a text input.
    /// Params:
    ///     params      = Node parameters.
    ///     placeholder = Placeholder text for the field.
    ///     submitted   = Callback for when the field is submitted.
    this(NodeParams params, string placeholder = "", void delegate() @trusted submitted = null) {

        super(params);
        this.placeholder = placeholder;
        this.submitted = submitted;

        // Create the label
        this.contentLabel = new typeof(contentLabel)(NodeParams(.layout!(1, "fill")), "");

        with (this.contentLabel) {

            // Make the scrollbar invisible
            scrollBar.disable();
            scrollBar.width = 0;
            // Note: We're not hiding the scrollbar, so it may adjust used values to the size of the input

            disableWrap = true;
            ignoreMouse = true;

        }

    }

    protected override void resizeImpl(Vector2 area) {

        import std.algorithm : max;

        // Set the size
        minSize = size;

        // Set height to at least the font size
        minSize.y = max(minSize.y, style.font.lineHeight);

        // Set the label text
        contentLabel.text = (value == "") ? placeholder : value;

        // Inherit main style
        // TODO reuse the hashmap maybe?
        auto childTheme = theme.makeTheme!q{

            FluidLabel.styleAdd!q{

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

        import std.datetime : Clock;
        import std.algorithm : min, max;

        auto style = pickStyle();

        const scrollOffset = max(0, contentLabel.scrollMax - inner.w);

        // Fill the background
        style.drawBackground(tree.io, outer);

        // Copy the style to the label
        contentLabel.activeStyle = style;

        // Set the scroll
        contentLabel.scroll = cast(size_t) scrollOffset;

        // Draw the text
        contentLabel.draw(inner);

        // Ignore the rest if the node isn't focused
        if (!isFocused || isDisabledInherited) return;

        auto timeSecs = Clock.currTime.second;

        // Add a blinking caret
        if (timeSecs % (blinkTime*2) < blinkTime) {

            const lineHeight = style.typeface.lineHeight;
            const margin = style.typeface.lineHeight / 10f;

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
            io.drawLine(
                end - Vector2(0, lineHeight - margin),
                end - Vector2(0, margin),
                focusStyle.textColor
            );

        }

    }

    protected override bool keyboardImpl() @trusted {

        import std.uni : isAlpha, isWhite;
        import std.range : back;
        import std.string : chop;

        string input;

        // Get pressed key
        while (true) {

            // Read text
            if (const key = io.inputCharacter) {

                // Append to char arrays
                input ~= cast(dchar) key;

            }

            // Stop if there's nothing left
            else break;

        }

        // Typed something
        if (input.length) {

            // Update the value
            value ~= input;

            // Trigger the callback
            if (changed) changed();

            // Update the size of the input
            updateSize();

            return true;

        }

        return true;

    }

    unittest {

        auto io = new HeadlessBackend;
        auto root = textInput("placeholder");

        root.io = io;

        // Empty text
        {
            root.draw();

            assert(root.value == "");
            assert(root.contentLabel.text == "placeholder");
            assert(root.contentLabel.activeStyle is root.emptyStyle);
        }

        // Focus the box and input stuff
        {
            io.nextFrame;
            io.inputCharacter("¡Hola, mundo!");
            root.focus();
            root.draw();

            assert(root.value == "¡Hola, mundo!");
        }

        // Input stuff
        {
            io.nextFrame;
            root.draw();

            assert(root.contentLabel.text == "¡Hola, mundo!");
            assert(root.contentLabel.activeStyle is root.focusStyle);
        }

    }

    /// Submit the input.
    @(FluidInputAction.submit)
    protected void _submit() {

        // Clear focus
        isFocused = false;

        // Run the callback
        if (submitted) submitted();

    }

    unittest {

        int submitted;

        auto io = new HeadlessBackend;
        FluidTextInput root;

        root = textInput("placeholder", delegate {
            submitted++;
            assert(root.value == "Hello World");
        });

        root.io = io;

        // Type stuff
        {
            root.value = "Hello World";
            root.focus();
            root.updateSize();
            root.draw();

            assert(submitted == 0);
            assert(root.value == "Hello World");
            assert(root.contentLabel.text == "Hello World");
        }

        // Submit
        {
            io.nextFrame;
            io.press(FluidKeyboardKey.enter);
            root.draw();

            assert(submitted == 1);
        }

    }

    /// Erase last inputted word.
    @(FluidInputAction.backspaceWord)
    void chopWord() {

        import std.uni;
        import std.range;

        // Run while there's something to process
        while (value != "") {

            // Remove the last character
            const lastChar = value.back;
            value = value.chop;

            // Stop if empty
            if (value == "") break;

            {

                // Continue if last removed character was whitespace
                if (lastChar.isWhite) continue;

                // Continue deleting if two last characters were alphanumeric, or neither of them was
                if (value.back.isAlphaNum == lastChar.isAlphaNum) continue;

            }

            // Break in other cases
            break;

        }

        // Trigger the callback
        if (changed) changed();

        // Update the size of the box
        updateSize();

    }

    unittest {

        auto io = new HeadlessBackend;
        auto root = textInput();

        root.io = io;

        // Type stuff
        {
            root.value = "Hello World";
            root.focus();
            root.updateSize();
            root.draw();

            assert(root.value == "Hello World");
            assert(root.contentLabel.text == "Hello World");
        }

        // Erase a word
        {
            io.nextFrame;
            root.chopWord;
            root.draw();

            assert(root.value == "Hello ");
            assert(root.contentLabel.text == "Hello ");
            assert(root.contentLabel.activeStyle is root.focusStyle);
        }

        // Erase a word
        {
            io.nextFrame;
            root.chopWord;
            root.draw();

            assert(root.value == "");
            assert(root.contentLabel.text == "");
            assert(root.contentLabel.activeStyle is root.emptyStyle);
        }

        // Typing should be disabled while erasing
        {
            io.press(FluidKeyboardKey.leftControl);
            io.press(FluidKeyboardKey.w);
            io.inputCharacter('w');

            root.draw();

            assert(root.value == "");
            assert(root.contentLabel.text == "");
            assert(root.contentLabel.activeStyle is root.emptyStyle);
        }

    }

    /// Erase last inputted letter.
    @(FluidInputAction.backspace)
    void chop() {

        // Ignore if the box is empty
        if (value == "") return;

        // Remove the last character
        value = value.chop;

        // Trigger the callback
        if (changed) changed();

        // Update the size of the box
        updateSize();

    }

    unittest {

        auto io = new HeadlessBackend;
        auto root = textInput();

        root.io = io;

        // Type stuff
        {
            root.value = "hello‽";
            root.focus();
            root.updateSize();
            root.draw();

            assert(root.value == "hello‽");
            assert(root.contentLabel.text == "hello‽");
        }

        // Erase a letter
        {
            io.nextFrame;
            root.chop;
            root.draw();

            assert(root.value == "hello");
            assert(root.contentLabel.text == "hello");
            assert(root.contentLabel.activeStyle is root.focusStyle);
        }

        // Erase a letter
        {
            io.nextFrame;
            root.chop;
            root.draw();

            assert(root.value == "hell");
            assert(root.contentLabel.text == "hell");
            assert(root.contentLabel.activeStyle is root.focusStyle);
        }

        // Typing should be disabled while erasing
        {
            io.press(FluidKeyboardKey.backspace);
            io.inputCharacter("o, world");

            root.draw();

            assert(root.value == "hel");
            assert(root.contentLabel.activeStyle is root.focusStyle);
        }

    }

    override inout(Style) pickStyle() inout {

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

private class TextImpl : FluidLabel {

    mixin DefineStyles!(
        "activeStyle", q{ style }
    );

    this(T...)(T args) {

        super(args);

    }

    // Same as parent, but doesn't draw background
    override void drawImpl(Rectangle outer, Rectangle inner) {

        const style = pickStyle();
        text.draw(style, inner);

    }

    override inout(Style) pickStyle() inout {

        return activeStyle;

    }

}
