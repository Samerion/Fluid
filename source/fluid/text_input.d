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
import fluid.popup_frame;


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

        /// Context menu for this input.
        PopupFrame contextMenu;

    }

    protected {

        /// If true, current movement action is performed while selecting.
        bool selectionMovement;

        /// Last padding box assigned to this node, with scroll applied.
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

        import fluid.button;

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

        // Create the context menu
        this.contextMenu = popupFrame(
            button(
                .layout!"fill",
                "Cut",
                delegate {
                    cut();
                    contextMenu.hide();
                }
            ),
            button(
                .layout!"fill",
                "Copy",
                delegate {
                    copy();
                    contextMenu.hide();
                }
            ),
            button(
                .layout!"fill",
                "Paste",
                delegate {
                    paste();
                    contextMenu.hide();
                }
            ),
        );

    }

    /// Mark the text input as modified.
    void touch() {

        lastTouch = Clock.currTime;

    }

    /// Value written in the input.
    ///
    /// Warning: For security reasons, the contents of array will be overwritted by any change made to the content.
    /// Make sure to `dup` the output if you intend to keep the result.
    inout(char)[] value() inout {

        return _value;

    }

    /// ditto
    char[] value(char[] value) {

        replaceValue(value);
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
    char[] valueBeforeCaret(char[] newValue) {

        // Replace the data
        if (valueAfterCaret.empty)
            replaceValue(newValue);
        else
            replaceValue(newValue ~ valueAfterCaret);

        caretIndex = newValue.length;
        updateSize();

        return _value[0 .. caretIndex];

    }

    /// Get or set currently selected text.
    inout(char)[] selectedValue() inout {

        return _value[selectionLowIndex .. selectionHighIndex];

    }

    /// ditto
    char[] selectedValue(char[] value) {

        const isLow = caretIndex == selectionStart;
        const low = selectionLowIndex;
        const high = selectionHighIndex;

        replaceValue(_value[0 .. low] ~ value ~ _value[high .. $]);
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
    char[] valueAfterCaret(char[] newValue) {

        // Replace the data
        if (valueBeforeCaret.empty)
            replaceValue(newValue);
        else
            replaceValue(valueBeforeCaret ~ newValue);

        updateSize();

        return _value[caretIndex .. $];

    }

    /// Replace the value in a secure manner.
    private void replaceValue(char[] newValue) {

        const oldStart = cast(size_t) value.ptr;
        const oldEnd   = oldStart + value.length;
        const newStart = cast(size_t) newValue.ptr;
        const newEnd   = newStart + newValue.length;

        // TODO TextInput should probably handle reallocation on its own

        // Filter vertical space
        if (!multiline) {

            const joinedLength = Typeface.lineSplitter(newValue).joiner.byChar.walkLength;

            // Found vertical space
            if (joinedLength != newValue.length) {

                newValue = Typeface.lineSplitter(newValue).join(' ');

            }

        }

        // No value present, no shredding is to be done
        if (_value is null) {

            _value = newValue;
            return;

        }

        // If there is no overlap between the two strings, shred the old data in its entirety
        if (newStart >= oldEnd || newEnd <= oldStart || newValue is null) {

            _value[] = char.init;
            _value = newValue;
            return;

        }

        // Overlap exists:

        // Discarded start, shred that part
        if (newStart > oldStart) {
            _value[0 .. newStart - oldStart] = char.init;
        }

        // Discarded end
        if (newEnd < oldEnd) {
            _value[$ + newEnd - oldEnd .. $] = char.init;
        }

        _value = newValue;

    }

    unittest {

        char[] paddedValue = "0hello0".dup;
        char[] value = paddedValue[1 .. $-1];
        auto root = new TextInput;

        // Put the value in
        root.replaceValue(value);

        // Remove the first character
        root.replaceValue(value[1 .. $]);

        assert(value == "\xffello");

        // Remove the last character
        root.replaceValue(value[1 .. $-1]);

        assert(value == "\xffell\xff");

        // Remove both at once
        root.replaceValue(value[2 .. $-2]);

        assert(value == "\xff\xffl\xff\xff");

        // Replace the entire string
        char[] newValue = "world".dup;

        root.replaceValue(newValue);

        assert(value == "\xff\xff\xff\xff\xff");
        assert(paddedValue == "0\xff\xff\xff\xff\xff0");
        assert(newValue == "world");
        assert(root.value == newValue);

    }

    unittest {

        auto root = textInput();

        root.value = "hello wörld!".dup;
        assert(root.value == "hello wörld!");

        root.value = "hello wörld!\n".dup;
        assert(root.value == "hello wörld! ");

        root.value = "hello wörld!\r\n".dup;
        assert(root.value == "hello wörld! ");

        root.value = "hello wörld!\v".dup;
        assert(root.value == "hello wörld! ");

    }

    unittest {

        auto root = textInput(.multiline);

        root.value = "hello wörld!".dup;
        assert(root.value == "hello wörld!");

        root.value = "hello wörld!\n".dup;
        assert(root.value == "hello wörld!\n");

        root.value = "hello wörld!\r\n".dup;
        assert(root.value == "hello wörld!\r\n");

        root.value = "hello wörld!\v".dup;
        assert(root.value == "hello wörld!\v");

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
    ///
    /// Note that `selectionStart` may be greater than `selectionEnd`. If you need them in order, use
    /// `selectionLowIndex` and `selectionHighIndex`.
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

    /// Update the caret position to match the caret index.
    ///
    /// ## preferNextLine
    ///
    /// Determines if, in case text wraps over the new line, and the caret is in an ambiguous position, the caret
    /// will move to the next line, or stay on the previous one. Usually `false`, except for arrow keys and the
    /// "home" key.
    ///
    /// In cases where the text wraps over to the new line due to lack of space, the implied line break creates an
    /// ambiguous position for the caret. The caret may be placed either at the end of the original line, or be put
    /// on the newly created line:
    ///
    /// ---
    /// Lorem ipsum dolor sit amet, consectetur |
    /// |adipiscing elit, sed do eiusmod tempor
    /// ---
    ///
    /// Depending on the situation, either position may be preferable. Keep in mind that the caret position influences
    /// further movement, particularly when navigating using the down and up arrows. In case the caret is at the
    /// end of the line, it should stay close to the end, but when it's at the beginning, it should stay close to the
    /// start.
    ///
    /// This is not an issue at all on explicitly created lines, since the caret position is easily decided upon
    /// depending if it is preceding the line break, or if it's following one. This property is only used for implicitly
    /// created lines.
    void updateCaretPosition(bool preferNextLine = false) {

        import std.math : isNaN;

        // No available width, waiting for resize
        if (_availableWidth.isNaN) return;

        _caretPosition = caretPositionImpl(_availableWidth, preferNextLine);

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
        search: foreach (index, line; typeface.lineSplitterIndex(value)) {

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

    protected Vector2 caretPositionImpl(float textWidth, bool preferNextLine) {

        const(char)[] unbreakableChars(const char[] value) {

            // Split on lines
            auto lines = Typeface.lineSplitter(value);
            if (lines.empty) return value.init;

            // Split on words
            auto chunks = Typeface.defaultWordChunks(lines.front);
            if (chunks.empty) return value.init;

            // Return empty string if the result starts with whitespace
            if (chunks.front.front.isWhite) return value.init;

            // Return first word only
            return chunks.front;

        }

        // Check if the caret follows unbreakable characters
        const head = unbreakableChars(
            valueBeforeCaret.wordBack(true)
        );

        // If the caret is surrounded by unbreakable characters, include them in the output to make sure the
        // word is wrapped correctly
        const tail = preferNextLine || !head.empty
            ? unbreakableChars(valueAfterCaret)
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

        // Save the inner box
        _inner = scrolledInner;

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

        auto style = pickStyle();
        auto typeface = style.getTypeface;
        auto ruler = textRuler();

        Vector2 lineStart;
        Vector2 lineEnd;

        // Run through the text
        foreach (index, line; typeface.lineSplitterIndex(value)) {

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

        // Add a blinking caret if there is no selection
        return selectionStart == selectionEnd && timeSecs % 2 == 0;

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
    void push(char[] text) {

        import std.utf : encode;

        // If selection is active, overwrite the selection
        if (isSelecting) {

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

    unittest {

        auto root = textInput();

        root.push("hello".dup);
        root.runInputAction!(FluidInputAction.breakLine);

        assert(root.value == "hello");

    }

    unittest {

        auto root = textInput(.multiline);

        root.push("hello".dup);
        root.runInputAction!(FluidInputAction.breakLine);

        assert(root.value == "hello\n");

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

    unittest {

        int submitted;
        auto io = new HeadlessBackend;
        auto root = textInput(
            .multiline,
            "",
            delegate {
                submitted++;
            }
        );

        root.io = io;
        root.push("Hello, World!".dup);

        // Press enter (not focused)
        io.press(KeyboardKey.enter);
        root.draw();

        // No effect
        assert(root.value == "Hello, World!");
        assert(submitted == 0);

        // Focus for the next frame
        io.nextFrame();
        root.focus();

        // Press enter
        io.press(KeyboardKey.enter);
        root.draw();

        // A new line should be added
        assert(root.value == "Hello, World!\n");
        assert(submitted == 0);

        // Press ctrl+enter
        io.nextFrame();
        io.press(KeyboardKey.leftControl);
        io.press(KeyboardKey.enter);
        root.draw();

        // Input should be submitted
        assert(root.value == "Hello, World!\n");
        assert(submitted == 1);

    }

    /// Erase last word before the caret, or the first word after.
    ///
    /// Parms:
    ///     forward = If true, delete the next word. If false, delete the previous.
    void chopWord(bool forward = false) {

        import std.uni;
        import std.range;

        // Selection active, delete it
        if (isSelecting) {

            selectedValue = null;

        }

        // Remove next word
        else if (forward) {

            // Find the word to delete
            const erasedWord = valueAfterCaret.wordFront;

            // Remove the word
            valueAfterCaret = valueAfterCaret[erasedWord.length .. $];

        }

        // Remove previous word
        else {

            // Find the word to delete
            const erasedWord = valueBeforeCaret.wordBack;

            // Remove the word
            valueBeforeCaret = valueBeforeCaret[0 .. $ - erasedWord.length];

        }

        // Update the size of the box
        updateSize();
        updateCaretPosition();
        horizontalAnchor = caretPosition.x;

    }

    @(FluidInputAction.backspaceWord)
    protected void onBackspaceWord() {

        chopWord();
        _changed();

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

    @(FluidInputAction.deleteWord)
    protected void onDeleteWord() {

        chopWord(true);
        _changed();

    }

    unittest {

        auto root = textInput();

        // deleteWord should do nothing, because the caret is at the end
        root.push("Hello, Wörld".dup);
        root.runInputAction!(FluidInputAction.deleteWord);

        assert(!root.isSelecting);
        assert(root.value == "Hello, Wörld");
        assert(root.caretIndex == "Hello, Wörld".length);

        // Move it to the previous word
        root.runInputAction!(FluidInputAction.previousWord);

        assert(!root.isSelecting);
        assert(root.value == "Hello, Wörld");
        assert(root.caretIndex == "Hello, ".length);

        // Delete the next word
        root.runInputAction!(FluidInputAction.deleteWord);

        assert(!root.isSelecting);
        assert(root.value == "Hello, ");
        assert(root.caretIndex == "Hello, ".length);

        // Move to the start
        root.runInputAction!(FluidInputAction.toStart);

        assert(!root.isSelecting);
        assert(root.value == "Hello, ");
        assert(root.caretIndex == 0);

        // Delete the next word
        root.runInputAction!(FluidInputAction.deleteWord);

        assert(!root.isSelecting);
        assert(root.value == ", ");
        assert(root.caretIndex == 0);

        // Delete the next word
        root.runInputAction!(FluidInputAction.deleteWord);

        assert(!root.isSelecting);
        assert(root.value == "");
        assert(root.caretIndex == 0);

    }

    /// Erase any character preceding the caret, or the next one.
    /// Params:
    ///     forward = If true, removes character after the caret, otherwise removes the one before.
    void chop(bool forward = false) {

        // Selection active
        if (isSelecting) {

            selectedValue = null;

        }

        // Remove next character
        else if (forward) {

            if (valueAfterCaret == "") return;

            const length = valueAfterCaret.front.codeLength!char;

            valueAfterCaret = valueAfterCaret[length..$];

        }

        // Remove previous character
        else {

            if (valueBeforeCaret == "") return;

            const length = valueBeforeCaret.back.codeLength!char;

            valueBeforeCaret = valueBeforeCaret[0..$-length];

        }

        // Trigger the callback
        _changed();

        // Update the size of the box
        updateSize();
        updateCaretPosition();
        horizontalAnchor = caretPosition.x;

    }

    private {

        bool _pressed;

        /// Number of clicks performed within short enough time from each other. First click is number 0.
        int _clickCount;

        /// Time of the last `press` event, used to enable double click and triple click selection.
        SysTime _lastClick;

        /// Position of the last click.
        Vector2 _lastClickPosition;

    }

    protected override void mouseImpl() {

        enum maxDistance = 5;

        // Pressing with the mouse
        if (!tree.isMouseDown!(FluidInputAction.press)) return;

        const justPressed = !_pressed;

        // Just pressed
        if (justPressed) {

            const clickPosition = io.mousePosition;

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

        }

        // Move the caret with the mouse
        caretToMouse();
        moveOrClearSelection();

        final switch (_clickCount % 3) {

            // First click, merely move the caret while selecting
            case 0: break;

            // Second click, select the word surrounding the cursor
            case 1:
                selectWord();
                break;

            // Third click, select whole line
            case 2:
                selectLine();
                break;

        }

        // Enable selection mode
        // Disable it when releasing
        _pressed = selectionMovement = !tree.isMouseActive!(FluidInputAction.press);

    }

    unittest {

        // This test relies on properties of the default typeface

        import std.math : isClose;

        auto io = new HeadlessBackend;
        auto root = textInput(nullTheme.derive(
            rule!TextInput(
                Rule.selectionBackgroundColor = color("#02a"),
            ),
        ));

        root.io = io;
        root.value = "Hello, World! Foo, bar, scroll this input".dup;
        root.focus();
        root.draw();

        assert(root.contentLabel.scroll.isClose(127));

        // Select some stuff
        io.nextFrame;
        io.mousePosition = Vector2(150, 10);
        io.press();
        root.draw();

        io.nextFrame;
        io.mousePosition = Vector2(65, 10);
        root.draw();

        assert(root.selectedValue == "scroll this");

        io.nextFrame;
        root.draw();

        // Match the selection box
        io.assertRectangle(
            Rectangle(64, 0, 86, 27),
            color("#02a")
        );

    }

    unittest {

        // This test relies on properties of the default typeface

        import std.math : isClose;

        auto io = new HeadlessBackend;
        auto root = textInput(nullTheme.derive(
            rule!TextInput(
                Rule.selectionBackgroundColor = color("#02a"),
            ),
        ));

        root.io = io;
        root.value = "Hello, World! Foo, bar, scroll this input".dup;
        root.focus();
        root.draw();

        io.mousePosition = Vector2(150, 10);

        // Double- and triple-click
        foreach (i; 0..3) {

            io.nextFrame;
            io.press();
            root.draw();

            io.nextFrame;
            io.release();
            root.draw();

            // Double-clicked
            if (i == 1) {
                assert(root.selectedValue == "this");
            }

            // Triple-clicked
            if (i == 2) {
                assert(root.selectedValue == root.value);
            }

        }

        io.nextFrame;
        root.draw();

    }

    unittest {

        import std.math : isClose;

        auto io = new HeadlessBackend;
        auto theme = nullTheme.derive(
            rule!TextInput(
                Rule.selectionBackgroundColor = color("#02a"),
            ),
        );
        auto root = textInput(.multiline, theme);
        auto lineHeight = root.style.getTypeface.lineHeight;

        root.io = io;
        root.value = "Line one\nLine two\n\nLine four".dup;
        root.focus();
        root.draw();

        // Move the caret to second line
        root.caretIndex = "Line one\nLin".length;
        root.updateCaretPosition();

        const middle = root._inner.start + root.caretPosition;
        const top    = middle - Vector2(0, lineHeight);
        const blank  = middle + Vector2(0, lineHeight);
        const bottom = middle + Vector2(0, lineHeight * 2);

        {

            // Press, and move the mouse around
            io.nextFrame();
            io.mousePosition = middle;
            io.press();
            root.draw();

            // Move it to top row
            io.nextFrame();
            io.mousePosition = top;
            root.draw();

            assert(root.selectedValue == "e one\nLin");
            assert(root.selectionStart > root.selectionEnd);

            // Move it to bottom row
            io.nextFrame();
            io.mousePosition = bottom;
            root.draw();

            assert(root.selectedValue == "e two\n\nLin");
            assert(root.selectionStart < root.selectionEnd);

            // And to the blank line
            io.nextFrame();
            io.mousePosition = blank;
            root.draw();

            assert(root.selectedValue == "e two\n");
            assert(root.selectionStart < root.selectionEnd);

        }

        {

            // Double click
            io.mousePosition = middle;
            root._lastClick = SysTime.init;

            foreach (i; 0..2) {

                io.nextFrame();
                io.release();
                root.draw();

                io.nextFrame();
                io.press();
                root.draw();

            }

            assert(root.selectedValue == "Line");
            assert(root.selectionStart < root.selectionEnd);

            // Move it to top row
            io.nextFrame();
            io.mousePosition = top;
            root.draw();

            assert(root.selectedValue == "Line one\nLine");
            assert(root.selectionStart > root.selectionEnd);

            // Move it to bottom row
            io.nextFrame();
            io.mousePosition = bottom;
            root.draw();

            assert(root.selectedValue == "Line two\n\nLine");
            assert(root.selectionStart < root.selectionEnd);

            // And to the blank line
            io.nextFrame();
            io.mousePosition = blank;
            root.draw();

            assert(root.selectedValue == "Line two\n");
            assert(root.selectionStart < root.selectionEnd);

        }

        {

            // Triple
            io.mousePosition = middle;
            root._lastClick = SysTime.init;

            foreach (i; 0..3) {

                io.nextFrame();
                io.release();
                root.draw();

                io.nextFrame();
                io.press();
                root.draw();

            }

            assert(root.selectedValue == "Line two");
            assert(root.selectionStart < root.selectionEnd);

            // Move it to top row
            io.nextFrame();
            io.mousePosition = top;
            root.draw();

            assert(root.selectedValue == "Line one\nLine two");
            assert(root.selectionStart > root.selectionEnd);

            // Move it to bottom row
            io.nextFrame();
            io.mousePosition = bottom;
            root.draw();

            assert(root.selectedValue == "Line two\n\nLine four");
            assert(root.selectionStart < root.selectionEnd);

            // And to the blank line
            io.nextFrame();
            io.mousePosition = blank;
            root.draw();

            assert(root.selectedValue == "Line two\n");
            assert(root.selectionStart < root.selectionEnd);

        }

    }

    /// Open the context menu
    @(FluidInputAction.contextMenu)
    protected void onContextMenu() {

        // Move the caret
        if (!isSelecting)
            caretToMouse();

        // Spawn the popup
        tree.spawnPopup(contextMenu);

        // Anchor to caret position
        contextMenu.anchor = _inner.start + caretPosition;

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

        // Remove the value
        replaceValue(null);

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

        auto value1 = root.value;

        root.chop();

        assert(root.value == "Hello, World");
        assert(value1 == "Hello, World\xff");

        auto value2 = root.value;
        root.chopWord();

        assert(root.value == "Hello, ");
        assert(value2 == "Hello, \xff\xff\xff\xff\xff");
        assert(value1 == "Hello, \xff\xff\xff\xff\xff\xff");

        auto value3 = root.value;
        root.clear();

        assert(root.value == "");
        assert(value3 == "\xff\xff\xff\xff\xff\xff\xff");
        assert(value2 == "\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff");
        assert(value1 == "\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff");

    }

    unittest {

        // Security test
        auto io = new HeadlessBackend;
        auto root = textInput();

        io.inputCharacter("Hello, World");
        root.io = io;
        root.focus();
        root.draw();

        auto value1 = root.value;

        root.chopWord();

        assert(root.value == "Hello, ");
        assert(value1 == "Hello, \xff\xff\xff\xff\xff");

        auto value2 = root.value;

        root.push("Moon".dup);

        assert(root.value == "Hello, Moon");
        assert(value2 == "Hello, "
            || value2 == "\xff\xff\xff\xff\xff\xff\xff");
        assert(value1 == "Hello, Moon\xff"
            || value1 == "\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff");

        auto value3 = root.value;

        root.clear();

        assert(value3 == "\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff");
        assert(value2 == "\xff\xff\xff\xff\xff\xff\xff");
        assert(value1 == "\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff");

    }

    /// Select the word surrounding the cursor. If selection is active, expands selection to cover words.
    void selectWord() {

        enum excludeWhite = true;

        const isLow = selectionStart <= selectionEnd;
        const low = selectionLowIndex;
        const high = selectionHighIndex;

        const head = value[0 .. low].wordBack(excludeWhite);
        const tail = value[high .. $].wordFront(excludeWhite);

        // Set selection to the start of the word
        selectionStart = low - head.length;

        // Move the caret to the end of the word
        caretIndex = high + tail.length;

        // Swap them if order is reversed
        if (!isLow) swap(_selectionStart, _caretIndex);

        touch();
        updateCaretPosition(false);

    }

    /// Select the whole line the cursor is on.
    void selectLine() {

        const isLow = selectionStart <= selectionEnd;

        foreach (index, line; Typeface.lineSplitterIndex(value)) {

            const lineStart = index;
            const lineEnd = index + line.length;

            // Found selection start
            if (lineStart <= selectionStart && selectionStart <= lineEnd) {

                selectionStart = isLow
                    ? lineStart
                    : lineEnd;

            }

            // Found selection end
            if (lineStart <= selectionEnd && selectionEnd <= lineEnd) {

                selectionEnd = isLow
                    ? lineEnd
                    : lineStart;


            }

        }

        updateCaretPosition(false);

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

        updateCaretPosition(true);
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

        updateCaretPosition(true);
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
        updateCaretPosition(horizontalAnchor < 1);
        moveOrClearSelection();

    }

    /// Move the caret to the given position.
    void caretTo(Vector2 position) {

        caretIndex = nearestCharacter(position);

    }

    unittest {

        // Note: This test depends on parameters specific to the default typeface.

        import std.math : isClose;

        auto io = new HeadlessBackend;
        auto root = textInput(.nullTheme, .multiline);

        root.io = io;
        root.size = Vector2(200, 0);
        root.value = "Hello, World!\nHello, Moon\n\nHello, Sun\nWrap this line µp, make it long enough to cross over"
            .dup;
        root.draw();

        // Move the caret to different points on the canvas

        // Left side of the second "l" in "Hello", first line
        root.caretTo(Vector2(30, 10));
        assert(root.caretIndex == "Hel".length);

        // Right side of the same "l"
        root.caretTo(Vector2(33, 10));
        assert(root.caretIndex == "Hell".length);

        // Comma, right side, close to the second line
        root.caretTo(Vector2(50, 24));
        assert(root.caretIndex == "Hello,".length);

        // End of the line, far right
        root.caretTo(Vector2(200, 10));
        assert(root.caretIndex == "Hello, World!".length);

        // Start of the next line
        root.caretTo(Vector2(0, 30));
        assert(root.caretIndex == "Hello, World!\n".length);

        // Space, right between "Hello," and "Moon"
        root.caretTo(Vector2(54, 40));
        assert(root.caretIndex == "Hello, World!\nHello, ".length);

        // Empty line
        root.caretTo(Vector2(54, 60));
        assert(root.caretIndex == "Hello, World!\nHello, Moon\n".length);

        // Beginning of the next line; left side of the "H"
        root.caretTo(Vector2(4, 85));
        assert(root.caretIndex == "Hello, World!\nHello, Moon\n\n".length);

        // Wrapped line, the bottom of letter "p" in "up"
        root.caretTo(Vector2(142, 128));
        assert(root.caretIndex == "Hello, World!\nHello, Moon\n\nHello, Sun\nWrap this line µp".length);

        // End of line
        root.caretTo(Vector2(160, 128));
        assert(root.caretIndex == "Hello, World!\nHello, Moon\n\nHello, Sun\nWrap this line µp, ".length);

        // Beginning of the next line; result should be the same
        root.caretTo(Vector2(2, 148));
        assert(root.caretIndex == "Hello, World!\nHello, Moon\n\nHello, Sun\nWrap this line µp, ".length);

        // Just by the way, check if the caret position is correct
        root.updateCaretPosition(true);
        assert(root.caretPosition.x.isClose(0));
        assert(root.caretPosition.y.isClose(135));

        root.updateCaretPosition(false);
        assert(root.caretPosition.x.isClose(153));
        assert(root.caretPosition.y.isClose(108));

        // Try the same with the third line
        root.caretTo(Vector2(200, 148));
        assert(root.caretIndex
            == "Hello, World!\nHello, Moon\n\nHello, Sun\nWrap this line µp, make it long enough ".length);
        root.caretTo(Vector2(2, 168));
        assert(root.caretIndex
            == "Hello, World!\nHello, Moon\n\nHello, Sun\nWrap this line µp, make it long enough ".length);

    }

    /// Move the caret to mouse position.
    void caretToMouse() {

        caretTo(io.mousePosition - _inner.start);
        updateCaretPosition(false);
        horizontalAnchor = caretPosition.x;

    }

    unittest {

        import std.math : isClose;

        // caretToMouse is a just a wrapper over caretTo, enabling mouse input
        // This test checks if it correctly maps mouse coordinates to internal coordinates

        auto io = new HeadlessBackend;
        auto theme = nullTheme.derive(
            rule!TextInput(
                Rule.margin = 40,
                Rule.padding = 40,
            )
        );
        auto root = textInput(.multiline, theme);

        root.io = io;
        root.size = Vector2(200, 0);
        root.value = "123\n456\n789"
            .dup;
        root.draw();

        io.nextFrame();
        io.mousePosition = Vector2(140, 90);
        root.caretToMouse();

        assert(root.caretIndex == 3);

    }

    /// Move the caret to the beginning of the line.
    @(FluidInputAction.toLineStart)
    void caretToLineStart() {

        const search = Vector2(0, caretPosition.y);

        caretTo(search);
        updateCaretPosition(true);
        moveOrClearSelection();
        horizontalAnchor = caretPosition.x;

    }

    /// Move the caret to the end of the line.
    @(FluidInputAction.toLineEnd)
    void caretToLineEnd() {

        const search = Vector2(float.infinity, caretPosition.y);

        caretTo(search);
        updateCaretPosition(false);
        moveOrClearSelection();
        horizontalAnchor = caretPosition.x;

    }

    unittest {

        // Note: This test depends on parameters specific to the default typeface.

        import std.math : isClose;

        auto io = new HeadlessBackend;
        auto root = textInput(.nullTheme, .multiline);

        root.io = io;
        root.size = Vector2(200, 0);
        root.value = "Hello, World!\nHello, Moon\n\nHello, Sun\nWrap this line µp, make it long enough to cross over"
            .dup;
        root.focus();
        root.draw();

        root.caretIndex = 0;
        root.updateCaretPosition();
        root.runInputAction!(FluidInputAction.toLineEnd);

        assert(root.caretIndex == "Hello, World!".length);

        // Move to the next line, should be at the end
        root.runInputAction!(FluidInputAction.nextLine);

        assert(root.valueBeforeCaret.wordBack == "Moon");
        assert(root.valueAfterCaret.wordFront == "\n\n");

        // Move to the blank line
        root.runInputAction!(FluidInputAction.nextLine);

        const blankLine = root.caretIndex;
        assert(root.valueBeforeCaret.wordBack == "Moon\n");
        assert(root.valueAfterCaret.wordFront == "\n");

        // toLineEnd and toLineStart should have no effect
        root.runInputAction!(FluidInputAction.toLineStart);
        assert(root.caretIndex == blankLine);
        root.runInputAction!(FluidInputAction.toLineEnd);
        assert(root.caretIndex == blankLine);

        // Next line again
        // The anchor has been reset to the beginning
        root.runInputAction!(FluidInputAction.nextLine);

        assert(root.valueBeforeCaret.wordBack == "Moon\n\n");
        assert(root.valueAfterCaret.wordFront == "Hello");

        // Move to the very end
        root.runInputAction!(FluidInputAction.toEnd);

        assert(root.valueBeforeCaret.wordBack == "over");
        assert(root.valueAfterCaret.wordFront == "");

        // Move to start of the line
        root.runInputAction!(FluidInputAction.toLineStart);

        assert(root.valueBeforeCaret.wordBack == "enough ");
        assert(root.valueAfterCaret.wordFront == "to ");
        assert(root.caretPosition.x.isClose(0));

        // Move to the previous line
        root.runInputAction!(FluidInputAction.previousLine);

        assert(root.valueBeforeCaret.wordBack == ", ");
        assert(root.valueAfterCaret.wordFront == "make ");
        assert(root.caretPosition.x.isClose(0));

        // Move to its end — position should be the same as earlier, but the caret should be on the same line
        root.runInputAction!(FluidInputAction.toLineEnd);

        assert(root.valueBeforeCaret.wordBack == "enough ");
        assert(root.valueAfterCaret.wordFront == "to ");
        assert(root.caretPosition.x.isClose(181));

        // Move to the previous line — again
        root.runInputAction!(FluidInputAction.previousLine);

        assert(root.valueBeforeCaret.wordBack == ", ");
        assert(root.valueAfterCaret.wordFront == "make ");
        assert(root.caretPosition.x.isClose(153));

    }

    /// Move the caret to the beginning of the input
    @(FluidInputAction.toStart)
    void caretToStart() {

        caretIndex = 0;
        updateCaretPosition(true);
        moveOrClearSelection();
        horizontalAnchor = caretPosition.x;

    }

    /// Move the caret to the end of the input
    @(FluidInputAction.toEnd)
    void caretToEnd() {

        caretIndex = value.length;
        updateCaretPosition(false);
        moveOrClearSelection();
        horizontalAnchor = caretPosition.x;

    }

    /// Select all text
    @(FluidInputAction.selectAll)
    void selectAll() {

        selectionMovement = true;
        scope (exit) selectionMovement = false;

        _selectionStart = 0;
        caretToEnd();

    }

    unittest {

        auto root = textInput();

        root.draw();
        root.selectAll();

        assert(root.selectionStart == 0);
        assert(root.selectionEnd == 0);

        root.push("foo bar ".dup);

        assert(!root.isSelecting);

        root.push("baz".dup);

        assert(root.value == "foo bar baz");

        auto value1 = root.value;

        root.selectAll();

        assert(root.selectionStart == 0);
        assert(root.selectionEnd == root.value.length);

        root.push("replaced".dup);

        assert(root.value == "replaced");
        assert(value1 == "\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff");

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
            default:
                assert(false, "Invalid action");
        }

    }

    /// Cut selected text to clipboard, clearing the selection.
    @(FluidInputAction.cut)
    protected void cut() {

        copy();
        selectedValue = null;

    }

    unittest {

        auto root = textInput();

        root.draw();

        root.push("Foo Bar Baz Ban".dup);

        // Move cursor to "Bar"
        root.runInputAction!(FluidInputAction.toStart);
        root.runInputAction!(FluidInputAction.nextWord);

        // Select "Bar Baz "
        root.runInputAction!(FluidInputAction.selectNextWord);
        root.runInputAction!(FluidInputAction.selectNextWord);

        assert(root.io.clipboard == "");

        // Cut the text
        root.cut();

        assert(root.io.clipboard == "Bar Baz ");
        assert(root.value == "Foo Ban");

    }

    /// Copy selected text to clipboard.
    @(FluidInputAction.copy)
    protected void copy() {

        if (isSelecting)
            io.clipboard = selectedValue.idup;

    }

    unittest {

        auto root = textInput();

        root.draw();
        root.push("Foo Bar Baz Ban".dup);

        // Select all
        root.selectAll();

        assert(root.io.clipboard == "");

        root.copy();

        assert(root.io.clipboard == "Foo Bar Baz Ban");

        // Reduce selection by a word
        root.runInputAction!(FluidInputAction.selectPreviousWord);
        root.copy();

        assert(root.io.clipboard == "Foo Bar Baz ");
        assert(root.value == "Foo Bar Baz Ban");

    }

    /// Paste text from clipboard.
    @(FluidInputAction.paste)
    protected void paste() {

        push(io.clipboard.dup);

    }

    unittest {

        auto root = textInput();

        root.value = "Foo ".dup;
        root.draw();
        root.io.clipboard = "Bar";

        assert(root.caretIndex == 4);
        assert(root.value == "Foo ");

        root.paste();

        assert(root.caretIndex == 7);
        assert(root.value == "Foo Bar");

        root.caretToStart();
        root.paste();

        assert(root.caretIndex == 3);
        assert(root.value == "BarFoo Bar");

    }

}

unittest {

    auto root = textInput(.nullTheme, .multiline);
    auto lineHeight = root.style.getTypeface.lineHeight;

    root.value = "First one\nSecond two".dup;
    root.draw();

    // Navigate to the start and select the whole line
    root.caretToStart();
    root.runInputAction!(FluidInputAction.selectToLineEnd);

    assert(root.selectedValue == "First one");
    assert(root.caretPosition.y < lineHeight);

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
        text.draw(style, inner.start);

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
