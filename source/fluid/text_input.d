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

alias textInput = simpleConstructor!TextInput;

@safe:

/// Text input field.
class TextInput : InputNode!Node {

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
        Scrollable!(TextImpl, "true") contentLabel;

    }

    /// Create a text input.
    /// Params:
    ///     params      = Node parameters.
    ///     placeholder = Placeholder text for the field.
    ///     submitted   = Callback for when the field is submitted.
    this(string placeholder = "", void delegate() @trusted submitted = null) {

        this.placeholder = placeholder;
        this.submitted = submitted;

        // Create the label
        this.contentLabel = new typeof(contentLabel)("");

        with (this.contentLabel) {

            // Make the scrollbar invisible
            scrollBar.disable();
            scrollBar.width = 0;
            // Note: We're not hiding the scrollbar, so it may adjust used values to the size of the input

            disableWrap();
            ignoreMouse = true;

        }

    }

    bool isEmpty() const {

        return value == "";

    }

    protected override void resizeImpl(Vector2 area) {

        import std.algorithm : max;

        // Set the size
        minSize = size;

        // Set height to at least the font size
        minSize.y = max(minSize.y, style.font.lineHeight);

        // Set the label text
        contentLabel.text = (value == "") ? placeholder : value;

        // Resize the label
        contentLabel.resize(tree, theme, Vector2(0, minSize.y));

    }

    protected override void drawImpl(Rectangle outer, Rectangle inner) @trusted {

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
                style.textColor, //focusStyle.textColor
            );

        }

    }

    protected override bool keyboardImpl() @trusted {

        import std.uni : isAlpha, isWhite;
        import std.range : back;
        import std.string : chop;

        bool changed;

        // Get pressed key
        while (true) {

            // Read text
            if (const key = io.inputCharacter) {

                // Append to char arrays
                push(key);
                changed = true;

            }

            // Stop if there's nothing left
            else break;

        }

        // Typed something
        if (changed) {

            // Trigger the callback
            _changed();

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
            assert(root.isEmpty);
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
            assert(root.isFocused);
        }

    }

    /// Push a character to the input.
    void push(dchar character) {

        value ~= character;
        updateSize();

    }

    /// Called whenever the text input is updated.
    protected void _changed() {

        // Run the callback
        if (changed) changed();

    }

    deprecated("Use _submitted instead, _submit to be removed in 0.8.0")
    protected void _submit() {

        _submitted();

    }

    /// Submit the input.
    @(FluidInputAction.submit)
    protected void _submitted() {

        // Clear focus
        isFocused = false;

        // Run the callback
        if (submitted) submitted();

    }

    unittest {

        int submitted;

        auto io = new HeadlessBackend;
        TextInput root;

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
            io.press(KeyboardKey.enter);
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
        _changed();

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
            assert(root.isFocused);
        }

        // Erase a word
        {
            io.nextFrame;
            root.chopWord;
            root.draw();

            assert(root.value == "");
            assert(root.contentLabel.text == "");
            assert(root.isEmpty);
        }

        // Typing should be disabled while erasing
        {
            io.press(KeyboardKey.leftControl);
            io.press(KeyboardKey.w);
            io.inputCharacter('w');

            root.draw();

            assert(root.value == "");
            assert(root.contentLabel.text == "");
            assert(root.isEmpty);
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
        _changed();

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
            assert(root.isFocused);
        }

        // Erase a letter
        {
            io.nextFrame;
            root.chop;
            root.draw();

            assert(root.value == "hell");
            assert(root.contentLabel.text == "hell");
            assert(root.isFocused);
        }

        // Typing should be disabled while erasing
        {
            io.press(KeyboardKey.backspace);
            io.inputCharacter("o, world");

            root.draw();

            assert(root.value == "hel");
            assert(root.isFocused);
        }

    }

}

private class TextImpl : Label {

    Style activeStyle;

    this(T...)(T args) {

        super(args);
        activeStyle = Style.init;

    }

    override void drawImpl(Rectangle outer, Rectangle inner) {

        // Don't draw background
        const style = pickStyle();
        text.draw(style, inner);

    }

    override void reloadStyles() {

        super.reloadStyles();

        // Remove all spacing
        style.margin = 0;
        style.padding = 0;
        style.border = 0;

    }

    override Style pickStyle() {

        auto style = activeStyle;
        style.margin = 0;
        style.padding = 0;
        style.border = 0;
        return style;

    }

}
