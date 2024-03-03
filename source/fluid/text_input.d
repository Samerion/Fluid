///
module fluid.text_input;

import std.uni;
import std.utf;
import std.range;
import std.string;
import std.traits;
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

        /// A placeholder text for the field, displayed when the field is empty. Style using `emptyStyle`.
        string placeholder;

        /// Time of the last interaction with the input.
        SysTime lastTouch;

    }

    private {

        /// Underlying label controlling the content. Needed to properly adjust it to scroll.
        Scrollable!(TextImpl, "true") contentLabel;

        /// Value of the field.
        char[] _value;

        /// Available horizontal space.
        float _availableWidth = float.nan;

        /// Visual position of the caret.
        Vector2 _caretPosition;

        /// Index of the caret.
        ptrdiff_t _caretIndex;

    }

    /// Create a text input.
    /// Params:
    ///     placeholder = Placeholder text for the field.
    ///     submitted   = Callback for when the field is submitted.
    this(string placeholder = "", void delegate() @trusted submitted = null) {

        this.placeholder = placeholder;
        this.submitted = submitted;
        this.lastTouch = Clock.currTime;

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

    /// Mark the text input as modified.
    void touch() {

        lastTouch = Clock.currTime;

    }

    /// Value written in the input.
    ///
    /// Warning: The contents of this label may be overwritten by the input. Make sure to `dup` the output if you intend
    /// to keep the result.
    inout(char)[] value() inout {

        return _value;

    }

    /// ditto
    char[] value(char[] value) {

        _value = value;
        caretToEnd();
        return value;

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

    /// Get text preceding the caret.
    inout(char)[] valueBeforeCaret() inout {

        return _value[0 .. caretIndex];

    }

    /// Reassign text preceding the caret.
    char[] valueBeforeCaret(char[] newValue) {

        _value = newValue ~ valueAfterCaret;
        caretIndex = newValue.length;

        return _value[0 .. caretIndex];

    }

    /// Get text following the caret.
    inout(char)[] valueAfterCaret() inout {

        return _value[caretIndex .. $];

    }

    /// Reassign text after the caret.
    char[] valueAfterCaret(char[] newValue) {

        _value = valueBeforeCaret ~ newValue;

        return _value[caretIndex .. $];

    }

    /// Visual position of the caret, relative to the top-left corner of the input.
    Vector2 caretPosition() const {

        return _caretPosition;

    }

    /// Index of the character, byte-wise.
    ptrdiff_t caretIndex() const {

        return _caretIndex.clamp(0, value.length);

    }

    ptrdiff_t caretIndex(ptrdiff_t index) {

        return _caretIndex = index;

    }

    // Move the caret to the beginning of the input
    @(FluidInputAction.toStart)
    void caretToStart() {

        _caretIndex = 0;
        updateCaretPosition();

    }

    /// Move the caret to the end of the input
    @(FluidInputAction.toEnd)
    void caretToEnd() {

        _caretIndex = value.length;
        updateCaretPosition();

    }

    protected override void resizeImpl(Vector2 area) {

        // Set the size
        minSize = size;

        // Set the label text
        contentLabel.text = (value == "") ? placeholder : value;

        const textArea = multiline
            ? Vector2(size.x, area.y)
            : Vector2(0, minSize.y);

        _availableWidth = textArea.x;

        // Resize the label
        contentLabel.activeStyle = style;
        contentLabel.resize(tree, theme, textArea);

        const minLines = multiline ? 3 : 1;

        // Set height to at least the font size, or total text size
        minSize.y = max(minSize.y, style.getTypeface.lineHeight * minLines, contentLabel.minSize.y);

        // Locate the cursor
        updateCaretPosition();

    }

    void updateCaretPosition() {

        import std.math : isNaN;

        // No available width, waiting for resize
        if (_availableWidth.isNaN) return;

        _caretPosition = caretPositionImpl(_availableWidth);

    }

    protected Vector2 caretPositionImpl(float textWidth) {

        import fluid.typeface : TextRuler;

        const space = multiline
            ? textWidth
            : float.nan;

        auto typeface = style.getTypeface;
        auto ruler = TextRuler(typeface, space);

        // Measure text until the caret
        typeface.measure(ruler, value[0 .. caretIndex], multiline);

        return Vector2(
            ruler.penPosition.x,
            max(ruler.textSize.y, typeface.lineHeight),
        );

    }

    protected override void drawImpl(Rectangle outer, Rectangle inner) @trusted {

        auto style = pickStyle();

        const scroll = contentLabel.scroll;
        const scrolledCaret = caretPosition.x - scroll;

        // Scroll to make sure the caret is always in view
        const scrollOffset
            = scrolledCaret > inner.width ? scrolledCaret - inner.width
            : scrolledCaret < 0           ? scrolledCaret
            : 0;

        // Fill the background
        style.drawBackground(tree.io, outer);

        // Copy the style to the label
        contentLabel.activeStyle = style;

        // Set the scroll
        contentLabel.setScroll = scroll + cast(ptrdiff_t) scrollOffset;

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
                min(relativeCaretPosition.x - contentLabel.scroll, inner.w),
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

        auto timeSecs = (Clock.currTime - lastTouch).total!"seconds";

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

        import std.utf : encode;

        char[4] buffer;

        auto size = buffer.encode(character);

        // Insert the character
        valueBeforeCaret = valueBeforeCaret ~ buffer[0..size];
        updateSize();
        touch();

    }

    /// Called whenever the text input is updated.
    protected void _changed() {

        // Mark as modified
        touch();

        // Run the callback
        if (changed) changed();

    }

    deprecated("Use _submitted instead, _submit to be removed in 0.8.0")
    protected void _submit() {

        _submitted();

    }

    /// Start a new line
    @(FluidInputAction.breakLine)
    protected bool _breakLine() {

        if (!multiline) return false;

        push('\n');

        return true;

    }

    /// Submit the input.
    @(FluidInputAction.submit)
    protected void _submitted() {

        import std.sumtype : match;

        // breakLine has higher priority, stop if it's active
        if (multiline && tree.isActive!(FluidInputAction.breakLine)) return;

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
            io.press(KeyboardKey.enter);
            root.draw();

            assert(submitted == 1);
        }

    }

    /// Erase last word before the caret, or the first word after.
    ///
    /// Parms:
    ///     forward = If true, delete the next word. If false, delete the previous.
    void chopWord(bool forward = false) {

        import std.uni;
        import std.range;

        char[] erasedWord;

        // Remove next word
        if (forward) {

            // Find the word to delete
            erasedWord = valueAfterCaret.wordFront;

            // Remove the word
            valueAfterCaret = valueAfterCaret[erasedWord.length .. $];

        }

        // Remove previous word
        else {

            // Find the word to delete
            erasedWord = valueBeforeCaret.wordBack;

            // Remove the word
            valueBeforeCaret = valueBeforeCaret[0 .. $ - erasedWord.length];

        }

        // Shred old data
        erasedWord[] = char.init;

        // Trigger the callback
        _changed();

        // Update the size of the box
        updateSize();

    }

    @(FluidInputAction.backspaceWord)
    protected void _backspaceWord() {

        return chopWord();

    }

    @(FluidInputAction.deleteWord)
    protected void _deleteWord() {

        return chopWord(true);

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

    /// Erase any character preceding the caret, or the next one.
    /// Params:
    ///     forward = If true, removes character after the caret, otherwise removes the one before.
    void chop(bool forward = false) {

        char[] erasedData;

        // Remove next character
        if (forward) {

            if (valueAfterCaret == "") return;

            const length = valueAfterCaret.front.codeLength!char;

            erasedData = valueAfterCaret[0..length];
            valueAfterCaret = valueAfterCaret[length..$];

        }

        // Remove previous character
        else {

            if (valueBeforeCaret == "") return;

            const length = valueBeforeCaret.back.codeLength!char;

            erasedData = valueBeforeCaret[$-length..$];
            valueBeforeCaret = valueBeforeCaret[0..$-length];

        }

        // Shred old data
        erasedData[] = char.init;

        // Trigger the callback
        _changed();

        // Update the size of the box
        updateSize();

    }

    @(FluidInputAction.backspace)
    protected void _backspace() {

        chop();

    }

    @(FluidInputAction.deleteChar)
    protected void _deleteChar() {

        chop(true);

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

        value = root.value;
        root.chopWord();

        assert(root.value == "Hello, ");
        assert(value == "Hello, \xff\xff\xff\xff\xff");

        value = root.value;
        root.clear();

        assert(root.value == "");
        assert(value == "\xff\xff\xff\xff\xff\xff\xff");

    }

    /// Move caret to the next character
    @(FluidInputAction.previousChar, FluidInputAction.nextChar)
    protected void _caretX(FluidInputAction action) {

        const direction = action == FluidInputAction.previousChar
            ? -1
            : +1;

        caretIndex = caretIndex + direction;
        touch();
        updateCaretPosition();

    }

    /// Move caret to the next word
    @(FluidInputAction.previousWord, FluidInputAction.nextWord)
    protected void _caretWord(FluidInputAction action) {

        // Previous word
        if (action == FluidInputAction.previousWord) {

            caretIndex = caretIndex - valueBeforeCaret.wordBack.length;

        }

        // Next word
        else {

            caretIndex = caretIndex + valueAfterCaret.wordFront.length;

        }

        touch();
        updateCaretPosition();

    }

}

/// `wordFront` and `wordBack` get the word at the beginning or end of given string, respectively.
///
/// A word is a streak of consecutive characters — non-whitespace, either all alphanumeric or all not — followed by any
/// number of whitespace.
T[] wordFront(T)(T[] text)
if (isSomeString!(T[])) {

    size_t length;

    T[] result() { return text[0..length]; }
    T[] remaining() { return text[length..$]; }

    while (remaining != "") {

        // Get the first character
        const lastChar = remaining.front;
        length += lastChar.codeLength!T;

        // Stop if empty
        if (remaining == "") break;

        const nextChar = remaining.front;

        // Continue if the next character is whitespace
        // Includes any case where the previous character is followed by whitespace
        if (nextChar.isWhite) continue;

        // Stop if whitespace follows a non-white character
        else if (lastChar.isWhite) break;

        // Stop if the next character has different type
        else if (lastChar.isAlphaNum != nextChar.isAlphaNum) break;

    }

    return result;

}

/// ditto
T[] wordBack(T)(T[] text)
if (isSomeString!(T[])) {

    size_t length = text.length;

    T[] result() { return text[length..$]; }
    T[] remaining() { return text[0..length]; }

    while (remaining != "") {

        // Get the first character
        const lastChar = remaining.back;
        length -= lastChar.codeLength!T;

        // Stop if empty
        if (remaining == "") break;

        const nextChar = remaining.back;

        // Continue if the current character is whitespace
        // Inverse to `wordFront`
        if (lastChar.isWhite) continue;

        // Stop if whitespace follows a non-white character
        else if (nextChar.isWhite) break;

        // Stop if the next character has different type
        else if (lastChar.isAlphaNum != nextChar.isAlphaNum) break;

    }

    return result;

}

unittest {

    assert("hello world!".wordFront == "hello ");
    assert("hello, world!".wordFront == "hello");
    assert("hello world!".wordBack == "!");
    assert("hello world".wordBack == "world");
    assert("hello ".wordBack == "hello ");

    assert("witaj świecie!".wordFront == "witaj ");
    assert(" świecie!".wordFront == " ");
    assert("świecie!".wordFront == "świecie");
    assert("witaj świecie!".wordBack == "!");
    assert("witaj świecie".wordBack == "świecie");
    assert("witaj ".wordBack == "witaj ");

    assert("Всем привет!".wordFront == "Всем ");
    assert("привет!".wordFront == "привет");
    assert("!".wordFront == "!");

    // dstring
    assert("Всем привет!"d.wordFront == "Всем "d);
    assert("привет!"d.wordFront == "привет"d);
    assert("!"d.wordFront == "!"d);

    assert("Всем привет!"d.wordBack == "!"d);
    assert("Всем привет"d.wordBack == "привет"d);
    assert("Всем "d.wordBack == "Всем "d);

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
