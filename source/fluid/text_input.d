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
import fluid.typeface;


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

        /// Reference horizontal (X) position for vertical movement. Relative to the input's top-left corner.
        ///
        /// To make sure that vertical navigation via up/down arrows stays in the same column as it traverses lines of
        /// varying width, a reference position is saved to match the visual position of the last column. This is then
        /// used to match against characters on adjacent lines to find the one that is the closest. This ensures that
        /// even if cursor travels a large vertical distance, it stays close to the original horizontal position,
        /// without sliding to the left or right in the process.
        ///
        /// `horizontalAnchor` is updated any time the cursor moves horizontally, including mouse navigation.
        float horizontalAnchor;

    }

    protected {

        /// If true, current movement action is performed while selecting.
        bool selectionMovement;

        /// Last padding box assigned to this node.
        Rectangle _inner;

    }

    private {

        alias ContentLabel = Scrollable!(WrappedLabel, "true");

        /// Underlying label controlling the content. Needed to properly adjust it to scroll.
        ContentLabel _contentLabel;

        /// Value of the field.
        char[] _value;

        /// Available horizontal space.
        float _availableWidth = float.nan;

        /// Visual position of the caret.
        Vector2 _caretPosition;

        /// Index of the caret.
        ptrdiff_t _caretIndex;

        /// Reference point; beginning of selection. Set to -1 if there is no start.
        ptrdiff_t _selectionStart;

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
        this._contentLabel = new typeof(_contentLabel)("");

        with (this._contentLabel) {

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

    inout(ContentLabel) contentLabel() inout {

        return _contentLabel;

    }

    /// Get or set text preceding the caret.
    inout(char)[] valueBeforeCaret() inout {

        return _value[0 .. caretIndex];

    }

    /// ditto
    char[] valueBeforeCaret(scope const(char)[] newValue) {

        _value = newValue ~ valueAfterCaret;
        caretIndex = newValue.length;
        updateSize();

        return _value[0 .. caretIndex];

    }

    /// Get or set currently selected text.
    inout(char)[] selectedValue() inout {

        return _value[selectionLowIndex .. selectionHighIndex];

    }

    /// ditto
    char[] selectedValue(scope const(char)[] value) {

        const isLow = caretIndex == selectionStart;
        const low = selectionLowIndex;
        const high = selectionHighIndex;

        _value = _value[0 .. low] ~ value ~ _value[high .. $];
        caretIndex = low + value.length;
        updateSize();
        clearSelection();

        return _value[low .. low + value.length];

    }

    /// Get or set text following the caret.
    inout(char)[] valueAfterCaret() inout {

        return _value[caretIndex .. $];

    }

    /// ditto
    char[] valueAfterCaret(scope const(char)[] newValue) {

        _value = valueBeforeCaret ~ newValue;
        updateSize();

        return _value[caretIndex .. $];

    }

    /// Visual position of the caret, relative to the top-left corner of the input.
    Vector2 caretPosition() const {

        // Calculated in caretPositionImpl
        return _caretPosition;

    }

    /// Index of the character, byte-wise.
    ptrdiff_t caretIndex() const {

        return _caretIndex.clamp(0, value.length);

    }

    /// ditto
    ptrdiff_t caretIndex(ptrdiff_t index) {

        if (!isSelecting) {
            _selectionStart = index;
        }

        touch();
        return _caretIndex = index;

    }

    /// If true, there's an active selection.
    bool isSelecting() const {

        return selectionStart != caretIndex || selectionMovement;

    }

    /// Low index of the selection, left boundary, first index.
    ptrdiff_t selectionLowIndex() const {

        return min(selectionStart, selectionEnd);

    }

    /// High index of the selection, right boundary, second index.
    ptrdiff_t selectionHighIndex() const {

        return max(selectionStart, selectionEnd);

    }

    /// Point where selection begins. Caret is the other end of the selection.
    ptrdiff_t selectionStart() const {

        // Selection is present
        return _selectionStart.clamp(0, value.length);

    }

    /// ditto
    ptrdiff_t selectionStart(ptrdiff_t value) {

        return _selectionStart = value;

    }

    /// Point where selection ends. Corresponds to caret position.
    alias selectionEnd = caretIndex;

    ///
    void clearSelection() {

        _selectionStart = _caretIndex;

    }

    /// Clear selection if selection movement is disabled.
    protected void moveOrClearSelection() {

        if (!selectionMovement) {

            clearSelection();

        }

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

    /// Find the closest index to the given position.
    /// Returns: Index of the character. The index may be equal to character length.
    size_t nearestCharacter(Vector2 needle) const {

        import std.math : abs;

        auto ruler = textRuler();
        auto typeface = ruler.typeface;

        struct Position {
            size_t index;
            Vector2 position;
        }

        /// Returns the position (inside the word) of the character that is the closest to the needle.
        Position closest(Vector2 startPosition, Vector2 endPosition, const char[] word) {

            // Needle is before or after the word
            if (needle.x <= startPosition.x) return Position(0, startPosition);
            if (needle.x >= endPosition.x) return Position(word.length, endPosition);

            size_t index;
            auto match = Position(0, startPosition);

            // Search inside the word
            while (index < word.length) {

                decode(word, index);  // index by reference

                auto size = typeface.measure(word[0..index]);
                auto end = startPosition.x + size.x;
                auto half = (match.position.x + end)/2;

                // Hit left side of this character, or right side of the previous, return the previous character
                if (needle.x < half) break;

                match.index = index;
                match.position.x = startPosition.x + size.x;

            }

            return match;

        }

        auto result = Position(0, Vector2(float.infinity, float.infinity));

        // Search for a matching character on adjacent lines
        search: foreach (line; typeface.lineSplitter(value)) {

            size_t index = cast(size_t) line.ptr - cast(size_t) value.ptr;

            ruler.startLine();

            // Each word is a single, unbreakable unit
            foreach (word, penPosition; typeface.eachWord(ruler, line, multiline)) {

                scope (exit) index += word.length;

                // Find the middle of the word to use as a reference for vertical search
                const middleY = ruler.caret.center.y;

                // Skip this word if the closest match is closer vertically
                if (abs(result.position.y - needle.y) < abs(middleY - needle.y)) continue;

                // Find the words' closest horizontal position
                const newLine = ruler.wordLineIndex == 1;
                const startPosition = Vector2(penPosition.x, middleY);
                const endPosition = Vector2(ruler.penPosition.x, middleY);
                const reference = closest(startPosition, endPosition, word);

                // Skip if the closest match is still closer than the chosen reference
                if (!newLine && abs(result.position.x - needle.x) < abs(reference.position.x - needle.x)) continue;

                // Save the result if it's better
                result = reference;
                result.index += index;

            }

        }

        return result.index;

    }

    protected Vector2 caretPositionImpl(float textWidth) {

        // If the caret is in the middle of a word, include whatever is after the caret to make sure the word is
        // wrapped correctly
        const inWord = !valueBeforeCaret.wordBack.endsWith!isWhite;
        const tail = inWord
            ? valueAfterCaret.wordFront.stripRight
            : null;

        auto typeface = style.getTypeface;
        auto ruler = textRuler();
        auto slice = value[0 .. caretIndex + tail.length];

        // Measure text until the caret; include the word that follows to keep proper wrapping
        typeface.measure(ruler, slice, multiline);

        auto caretPosition = ruler.caret.start;

        // Measure the word itself, and remove it
        caretPosition.x -= typeface.measure(tail).x;

        return caretPosition;

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

        // Save the inner box
        _inner = inner;

        // Fill the background
        style.drawBackground(tree.io, outer);

        // Copy the style to the label
        contentLabel.activeStyle = style;

        // Set the scroll
        contentLabel.setScroll = scroll + cast(ptrdiff_t) scrollOffset;

        auto scrolledInner = inner;
        scrolledInner.x -= contentLabel.scroll;

        const lastScissors = tree.pushScissors(outer);
        scope (exit) tree.popScissors(lastScissors);

        // Draw the contents
        drawContents(inner, scrolledInner);

    }

    protected void drawContents(Rectangle inner, Rectangle scrolledInner) {

        // Draw selection
        drawSelection(scrolledInner);

        // Draw the text
        contentLabel.draw(inner);

        // Draw the caret
        drawCaret(scrolledInner);

    }

    protected void drawCaret(Rectangle inner) {

        // Ignore the rest if the node isn't focused
        if (!isFocused || isDisabledInherited) return;

        // Add a blinking caret
        if (showCaret) {

            const lineHeight = style.getTypeface.lineHeight;
            const margin = lineHeight / 10f;
            const relativeCaretPosition = this.caretPosition();
            const caretPosition = start(inner) + relativeCaretPosition;

            // Draw the caret
            io.drawLine(
                caretPosition + Vector2(0, margin),
                caretPosition - Vector2(0, margin - lineHeight),
                style.textColor,
            );

        }

    }

    /// Get an appropriate text ruler for this input.
    protected TextRuler textRuler() const {

        return TextRuler(style.getTypeface, multiline ? _availableWidth : float.nan);

    }

    /// Draw selection, if applicable.
    protected void drawSelection(Rectangle inner) {

        // Ignore if selection is empty
        if (selectionStart == selectionEnd) return;

        const low = selectionLowIndex;
        const high = selectionHighIndex;

        // Run through the text
        auto typeface = style.getTypeface;
        auto ruler = textRuler();

        Vector2 lineStart;
        Vector2 lineEnd;

        foreach (line; typeface.lineSplitter(value)) {

            size_t index = cast(size_t) line.ptr - cast(size_t) value.ptr;

            ruler.startLine();

            // Each word is a single, unbreakable unit
            foreach (word, penPosition; typeface.eachWord(ruler, line, multiline)) {

                const caret = ruler.caret(penPosition);
                const startIndex = index;
                const endIndex = index = index + word.length;

                const newLine = ruler.wordLineIndex == 1;

                scope (exit) lineEnd = ruler.caret.end;

                // New line started, flush the line
                if (newLine && startIndex > low) {

                    const rect = Rectangle(
                        (inner.start + lineStart).tupleof,
                        (lineEnd - lineStart).tupleof
                    );

                    lineStart = caret.start;
                    io.drawRectangle(rect, style.selectionBackgroundColor);

                }

                // Selection starts here
                if (startIndex <= low && low <= endIndex) {

                    const dent = typeface.measure(word[0 .. low - startIndex]);

                    lineStart = caret.start + Vector2(dent.x, 0);

                }

                // Selection ends here
                if (startIndex <= high && high <= endIndex) {

                    const dent = typeface.measure(word[0 .. high - startIndex]);
                    const lineEnd = caret.end + Vector2(dent.x, 0);
                    const rect = Rectangle(
                        (inner.start + lineStart).tupleof,
                        (lineEnd - lineStart).tupleof
                    );

                    io.drawRectangle(rect, style.selectionBackgroundColor);
                    return;

                }

            }

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

    /// Push a character or string to the input.
    void push(dchar character) {

        char[4] buffer;

        auto size = buffer.encode(character);
        push(buffer[0..size]);

    }

    /// ditto
    void push(scope const(char)[] text) {

        import std.utf : encode;

        // If selection is active, overwrite the selection
        if (isSelecting) {

            // Shred old value
            selectedValue[] = char.init;

            // Override with the character
            selectedValue = text;
            clearSelection();

        }

        // Insert the character before caret
        else {

            valueBeforeCaret = valueBeforeCaret ~ text;
            touch();

        }

        updateCaretPosition();
        horizontalAnchor = caretPosition.x;

    }

    /// Called whenever the text input is updated.
    protected void _changed() {

        // Mark as modified
        touch();

        // Run the callback
        if (changed) changed();

    }

    /// Start a new line
    @(FluidInputAction.breakLine)
    protected bool onBreakLine() {

        if (!multiline) return false;

        push('\n');

        return true;

    }

    /// Submit the input.
    @(FluidInputAction.submit)
    protected void onSubmit() {

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

        // Selection active, delete it
        if (isSelecting) {

            erasedWord = selectedValue;
            selectedValue = null;

        }

        // Remove next word
        else if (forward) {

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
        updateCaretPosition();
        horizontalAnchor = caretPosition.x;

    }

    @(FluidInputAction.backspaceWord)
    protected void onBackspaceWord() {

        return chopWord();

    }

    @(FluidInputAction.deleteWord)
    protected void onDeleteWord() {

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

        // Selection active
        if (isSelecting) {

            erasedData = selectedValue;
            selectedValue = null;

        }

        // Remove next character
        else if (forward) {

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
        updateCaretPosition();
        horizontalAnchor = caretPosition.x;

    }

    protected override void mouseImpl() {

        // Pressing with the mouse
        if (tree.isMouseDown!(FluidInputAction.press)) {

            // Move the caret
            caretTo(io.mousePosition - _inner.start);
            horizontalAnchor = caretPosition.x;
            moveOrClearSelection();

            // Enable selection mode
            // Disable it when releasing
            selectionMovement = !tree.isMouseActive!(FluidInputAction.press);

        }

    }

    private {

        /// Number of clicks performed within short enough time from each other. First click is number 0.
        int _clickCount;

        /// Time of the last `press` event, used to enable double click and triple click selection.
        SysTime _lastClick;

        /// Position of the last click.
        Vector2 _lastClickPosition;

    }

    /// Double and triple click detection. Single click is detected with `mouseImpl`.
    @(FluidInputAction.press)
    protected bool onPress() {

        enum maxDistance = 5;

        const clickPosition = io.mousePosition - _inner.start;

        // To count as repeated, the click must be within the specified double click time, and close enough
        // to the original location
        const isRepeated = Clock.currTime - _lastClick < io.doubleClickTime
            && distance(clickPosition, _lastClickPosition) < maxDistance;

        // Count repeated clicks
        _clickCount = isRepeated
            ? _clickCount + 1
            : 0;

        // Register the click
        _lastClick = Clock.currTime;
        _lastClickPosition = clickPosition;

        final switch (_clickCount % 3) {

            // First click
            case 0: return false;

            // Second click, select the word surrounding the cursor
            case 1:
                selectWord();
                break;

            // Third click, select whole line
            case 2:
                selectLine();
                break;

        }

        selectionMovement = false;
        return true;

    }

    @(FluidInputAction.backspace)
    protected void onBackspace() {

        chop();

    }

    @(FluidInputAction.deleteChar)
    protected void onDeleteChar() {

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

        clearSelection();
        updateCaretPosition();
        horizontalAnchor = caretPosition.x;

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

    /// Select the word surrounding the cursor.
    void selectWord() {

        enum excludeWhite = true;

        const head = valueBeforeCaret.wordBack(excludeWhite);
        const tail = valueAfterCaret.wordFront(excludeWhite);

        // Set selection to the start of the word
        selectionStart = caretIndex - head.length;

        // Move the caret to the end of the word
        caretIndex = caretIndex + tail.length;

        touch();
        updateCaretPosition();

    }

    /// Select the whole line the cursor is on.
    void selectLine() {

        foreach (line; Typeface.lineSplitter(value)) {

            const index = cast(size_t) line.ptr - cast(size_t) value.ptr;

            const lineStart = index;
            const lineEnd = index + line.length;

            // Found the caret
            if (lineStart <= caretIndex && caretIndex <= lineEnd) {

                caretIndex = lineEnd;
                selectionStart = lineStart;
                updateCaretPosition();

            }

        }

    }

    /// Move caret to the next character
    @(FluidInputAction.previousChar, FluidInputAction.nextChar)
    protected void onXChar(FluidInputAction action) {

        const forward = action == FluidInputAction.nextChar;

        // Terminating selection
        if (isSelecting && !selectionMovement) {

            // Move to either end of the selection
            caretIndex = forward
                ? selectionHighIndex
                : selectionLowIndex;
            clearSelection();

        }

        // Move to next character
        else if (forward) {

            if (valueAfterCaret == "") return;

            const length = valueAfterCaret.front.codeLength!char;

            caretIndex = caretIndex + length;

        }

        // Move to previous character
        else {

            if (valueBeforeCaret == "") return;

            const length = valueBeforeCaret.back.codeLength!char;

            caretIndex = caretIndex - length;

        }

        updateCaretPosition();
        horizontalAnchor = caretPosition.x;

    }

    /// Move caret to the next word
    @(FluidInputAction.previousWord, FluidInputAction.nextWord)
    protected void onXWord(FluidInputAction action) {

        // Previous word
        if (action == FluidInputAction.previousWord) {

            caretIndex = caretIndex - valueBeforeCaret.wordBack.length;

        }

        // Next word
        else {

            caretIndex = caretIndex + valueAfterCaret.wordFront.length;

        }

        updateCaretPosition();
        moveOrClearSelection();
        horizontalAnchor = caretPosition.x;

    }

    /// Move the caret to the previous or next line.
    @(FluidInputAction.previousLine, FluidInputAction.nextLine)
    protected void onXLine(FluidInputAction action) {

        auto typeface = style.getTypeface;
        auto search = Vector2(horizontalAnchor, caretPosition.y);

        // Next line
        if (action == FluidInputAction.nextLine) {

            search.y += typeface.lineHeight;

        }

        // Previous line
        else {

            search.y -= typeface.lineHeight;

        }

        caretTo(search);
        moveOrClearSelection();

    }

    /// Move the caret to the given position.
    void caretTo(Vector2 position) {

        caretIndex = nearestCharacter(position);
        updateCaretPosition();

    }

    /// Move the caret to the beginning of the line.
    @(FluidInputAction.toLineStart)
    void caretToLineStart() {

        const search = Vector2(0, caretPosition.y);

        caretTo(search);
        moveOrClearSelection();
        horizontalAnchor = caretPosition.x;

    }

    /// Move the caret to the end of the line.
    @(FluidInputAction.toLineEnd)
    void caretToLineEnd() {

        const search = Vector2(float.infinity, caretPosition.y);

        caretTo(search);
        moveOrClearSelection();
        horizontalAnchor = caretPosition.x;

    }

    /// Move the caret to the beginning of the input
    @(FluidInputAction.toStart)
    void caretToStart() {

        caretIndex = 0;
        updateCaretPosition();
        moveOrClearSelection();
        horizontalAnchor = caretPosition.x;

    }

    /// Move the caret to the end of the input
    @(FluidInputAction.toEnd)
    void caretToEnd() {

        caretIndex = value.length;
        updateCaretPosition();
        moveOrClearSelection();
        horizontalAnchor = caretPosition.x;

    }

    /// Begin or continue selection using given movement action.
    ///
    /// Use `selectionStart` and `selectionEnd` to define selection boundaries manually.
    @(
        FluidInputAction.selectPreviousChar,
        FluidInputAction.selectNextChar,
        FluidInputAction.selectPreviousWord,
        FluidInputAction.selectNextWord,
        FluidInputAction.selectPreviousLine,
        FluidInputAction.selectNextLine,
        FluidInputAction.selectAll,
        FluidInputAction.selectToLineStart,
        FluidInputAction.selectToLineEnd,
        FluidInputAction.selectToStart,
        FluidInputAction.selectToEnd,
    )
    protected void onSelectX(FluidInputAction action) {

        selectionMovement = true;
        scope (exit) selectionMovement = false;

        // Start selection
        if (!isSelecting)
        selectionStart = caretIndex;

        with (FluidInputAction) switch (action) {
            case selectPreviousChar:
                runInputAction!previousChar;
                break;
            case selectNextChar:
                runInputAction!nextChar;
                break;
            case selectPreviousWord:
                runInputAction!previousWord;
                break;
            case selectNextWord:
                runInputAction!nextWord;
                break;
            case selectPreviousLine:
                runInputAction!previousLine;
                break;
            case selectNextLine:
                runInputAction!nextLine;
                break;
            case selectToLineStart:
                runInputAction!toLineStart;
                break;
            case selectToLineEnd:
                runInputAction!toLineEnd;
                break;
            case selectToStart:
                runInputAction!toStart;
                break;
            case selectToEnd:
                runInputAction!toEnd;
                break;
            case selectAll:
                _selectionStart = 0;
                caretToEnd();
                break;
            default:
                assert(false, "Invalid action");
        }

    }

    /// Cut selected text to clipboard, clearing the selection.
    @(FluidInputAction.cut)
    protected void onCut() {

        onCopy();
        selectedValue = null;

    }

    /// Copy selected text to clipboard.
    @(FluidInputAction.copy)
    protected void onCopy() {

        if (isSelecting)
            io.clipboard = selectedValue.idup;

    }

    /// Paste text from clipboard.
    @(FluidInputAction.paste)
    protected void onPaste() {

        push(io.clipboard.dup);

    }

}

/// `wordFront` and `wordBack` get the word at the beginning or end of given string, respectively.
///
/// A word is a streak of consecutive characters — non-whitespace, either all alphanumeric or all not — followed by any
/// number of whitespace.
///
/// Params:
///     text = Text to scan for the word.
///     excludeWhite = If true, whitespace will not be included in the word.
T[] wordFront(T)(T[] text, bool excludeWhite = false)
if (isSomeString!(T[])) {

    size_t length;

    T[] result() { return text[0..length]; }
    T[] remaining() { return text[length..$]; }

    while (remaining != "") {

        // Get the first character
        const lastChar = remaining.front;

        // Exclude white characters if enabled
        if (excludeWhite && lastChar.isWhite) break;

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
T[] wordBack(T)(T[] text, bool excludeWhite = false)
if (isSomeString!(T[])) {

    size_t length = text.length;

    T[] result() { return text[length..$]; }
    T[] remaining() { return text[0..length]; }

    while (remaining != "") {

        // Get the first character
        const lastChar = remaining.back;

        // Exclude white characters if enabled
        if (excludeWhite && lastChar.isWhite) break;

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

    // Whitespace exclusion
    assert("witaj świecie!".wordFront(true) == "witaj");
    assert(" świecie!".wordFront(true) == "");
    assert("witaj świecie".wordBack(true) == "świecie");
    assert("witaj ".wordBack(true) == "");

}

private class WrappedLabel : Label {

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
