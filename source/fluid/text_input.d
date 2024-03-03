///
module fluid.text_input;

import std.string;
import std.datetime;
import std.algorithm;

import fluid.node;
import fluid.text;
import fluid.input;
import fluid.label;
import fluid.style;
import fluid.utils;
import fluid.scroll;
import fluid.backend;
import fluid.structs;


@safe:


/// Constructor parameter, enables multiline input in `TextInput`.
auto multiline(bool value = true) {

    struct Multiline {

        bool value;

        void apply(TextInput node) {
            node.multiline = value;
        }

    }

    return Multiline(value);

}


/// Text input field.
///
/// Text input field uses a mutable character array (`char[]`) for content rather than `string` to provide improved
/// security for sensitive inputs. Built-in methods and operations will overwrite any removed text to prevent it from
/// staying in memory.
alias textInput = simpleConstructor!TextInput;

/// ditto
class TextInput : InputNode!Node {

    mixin enableInputActions;

    public {

        /// Size of the field.
        auto size = Vector2(200, 0);

        /// Value of the field.
        char[] value;

        /// A placeholder text for the field, displayed when the field is empty. Style using `emptyStyle`.
        string placeholder;

        /// Time of the last change made to the input.
        SysTime lastChange;

    }

    private {

        /// Underlying label controlling the content. Needed to properly adjust it to scroll.
        Scrollable!(TextImpl, "true") contentLabel;

        /// Visual position of the caret.
        Vector2 _caretPosition;

        /// Index of the caret.
        size_t _caretIndex;

    }

    /// Create a text input.
    /// Params:
    ///     placeholder = Placeholder text for the field.
    ///     submitted   = Callback for when the field is submitted.
    this(string placeholder = "", void delegate() @trusted submitted = null) {

        this.placeholder = placeholder;
        this.submitted = submitted;
        this.lastChange = Clock.currTime;

        // Create the label
        this.contentLabel = new typeof(contentLabel)("");

        with (this.contentLabel) {

            // Make the scrollbar invisible
            scrollBar.disable();
            scrollBar.width = 0;
            // Note: We're not hiding the scrollbar, so it may adjust used values to the size of the input

            isWrapDisabled = true;
            ignoreMouse = true;

        }

    }

    /// If true, this input is currently empty.
    bool isEmpty() const {

        return value == "";

    }

    /// If true, this input accepts multiple inputs in the input; pressing "enter" will start a new line.
    ///
    /// Even if multiline is off, the value may still contain line feeds if inserted from code.
    bool multiline() const {

        return !contentLabel.isWrapDisabled;

    }

    /// ditto
    bool multiline(bool value) {

        contentLabel.isWrapDisabled = !value;
        return value;

    }

    inout(Label) label() inout {

        return contentLabel;

    }

    /// Visual position of the caret, relative to the top-left corner of the input.
    Vector2 caretPosition() const {

        return _caretPosition;

    }

    size_t caretIndex() const {

        return min(_caretIndex, value.length);

    }

    size_t caretIndex(size_t index) {

        return _caretIndex = index;

    }

    protected override void resizeImpl(Vector2 area) {

        // Set the size
        minSize = size;

        // Set the label text
        contentLabel.text = (value == "") ? placeholder : value;

        const textArea = multiline
            ? area
            : Vector2(0, minSize.y);

        // Resize the label
        contentLabel.activeStyle = style;
        contentLabel.resize(tree, theme, textArea);

        const minLines = multiline ? 3 : 1;

        // Set height to at least the font size, or total text size
        minSize.y = max(minSize.y, style.getTypeface.lineHeight * minLines, contentLabel.minSize.y);

        // Locate the cursor
        _caretPosition = caretPositionImpl(area);

    }

    protected Vector2 caretPositionImpl(Vector2 availableSpace) {

        import fluid.typeface : TextRuler;

        auto typeface = style.getTypeface;
        auto ruler = TextRuler(typeface, availableSpace.x);

        // Measure text until the caret
        typeface.measure(ruler, value[0 .. caretIndex], multiline);

        return Vector2(
            ruler.penPosition.x,
            max(ruler.textSize.y, typeface.lineHeight),
        );

    }

    protected override void drawImpl(Rectangle outer, Rectangle inner) @trusted {

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

        // Draw the caret
        drawCaret(inner);

    }

    protected void drawCaret(Rectangle inner) {

        // Ignore the rest if the node isn't focused
        if (!isFocused || isDisabledInherited) return;

        // Add a blinking caret
        if (showCaret) {

            const lineHeight = style.getTypeface.lineHeight;
            const margin = lineHeight / 10f;
            const relativeCaretPosition = this.caretPosition();
            const caretPosition = start(inner) + Vector2(
                min(relativeCaretPosition.x, inner.width),
                relativeCaretPosition.y,
            );

            // Draw the caret
            io.drawLine(
                caretPosition + Vector2(0, margin - lineHeight),
                caretPosition - Vector2(0, margin),
                style.textColor,
            );

        }

    }

    protected bool showCaret() {

        auto timeSecs = (Clock.currTime - lastChange).total!"seconds";

        // Add a blinking caret
        return timeSecs % 2 == 0;

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
        _caretIndex += 1;
        updateSize();

    }

    /// Called whenever the text input is updated.
    protected void _changed() {

        lastChange = Clock.currTime;

        // Run the callback
        if (changed) changed();

    }

    deprecated("Use _submitted instead, _submit to be removed in 0.8.0")
    protected void _submit() {

        _submitted();

    }

    /// Start a new line
    @(FluidInputAction.breakLine)
    protected void _breakLine() {

        if (!multiline) return;

        push('\n');

    }

    /// Submit the input.
    @(FluidInputAction.submit)
    protected void _submitted() {

        import std.sumtype : match;

        // breakLine has higher priority, stop if it's active
        if (multiline && tree.isActive!(FluidInputAction.breakLine)) return;

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
            root.value = "Hello World".dup;
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

        auto oldValue = value;

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

        const erased = oldValue.length - value.length;

        // Move the caret back
        _caretIndex -= erased;

        // Shred old data
        oldValue[value.length .. $] = char.init;

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
            root.value = "Hello World".dup;
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

        auto oldValue = value;

        // Ignore if the box is empty
        if (value == "") return;

        // Move the caret
        _caretIndex -= 1;

        // Remove the last character
        value = value.chop;

        // Shred old data
        oldValue[value.length .. $] = char.init;

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
            root.value = "hello‽".dup;
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

    /// Clear the value of this input field, making it empty.
    void clear()
    out(; isEmpty)
    do {

        // Shred the data
        value[] = char.init;

        // Remove the value
        value = null;

    }

    unittest {

        // Security test
        auto io = new HeadlessBackend;
        auto root = textInput();

        io.inputCharacter("Hello, World!");
        root.io = io;
        root.focus();
        root.draw();

        auto value = root.value;

        root.chop();

        assert(root.value == "Hello, World");
        assert(value == "Hello, World\xff");

        root.chopWord();

        assert(root.value == "Hello, ");
        assert(value == "Hello, \xff\xff\xff\xff\xff\xff");

        root.clear();

        assert(root.value == "");
        assert(value == "\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff");

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
