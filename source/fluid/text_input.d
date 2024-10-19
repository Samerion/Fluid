///
module fluid.text_input;

import std.uni;
import std.utf;
import std.range;
import std.string;
import std.traits;
import std.datetime;
import std.algorithm;
import std.container.dlist;

import fluid.node;
import fluid.text;
import fluid.input;
import fluid.label;
import fluid.style;
import fluid.utils;
import fluid.scroll;
import fluid.actions;
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
alias textInput = nodeBuilder!TextInput;
alias lineInput = nodeBuilder!TextInput;
alias multilineInput = nodeBuilder!(TextInput, (a) {
    a.multiline = true;
});

/// ditto
class TextInput : InputNode!Node, FluidScrollable {

    mixin enableInputActions;

    public {

        /// Size of the field.
        auto size = Vector2(200, 0);

        /// A placeholder text for the field, displayed when the field is empty. Style using `emptyStyle`.
        Rope placeholder;

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

        /// Underlying label controlling the content.
        ContentLabel contentLabel;

        /// Maximum entries in the history.
        int maxHistorySize = 256;

    }

    protected {

        static struct HistoryEntry {

            Rope value;
            size_t selectionStart;
            size_t selectionEnd;

            /// If true, the entry results from an action that was executed immediately after the last action, without
            /// changing caret position in the meantime.
            bool isContinuous;

            /// Change made by this entry.
            ///
            /// `first` and `second` should represent the old and new value respectively; `second` is effectively a
            /// substring of `value`.
            Rope.DiffRegion diff;

            /// A history entry is "additive" if it adds any new content to the input. An entry is "subtractive" if it
            /// removes any part of the input. An entry that replaces content is simultaneously additive and
            /// subtractive.
            ///
            /// See_Also: `setPreviousEntry`, `canMergeWith`
            bool isAdditive;

            /// ditto.
            bool isSubtractive;

            /// Set `isAdditive` and `isSubtractive` based on the given text representing the last input.
            void setPreviousEntry(HistoryEntry entry) {

                setPreviousEntry(entry.value);

            }

            /// ditto
            void setPreviousEntry(Rope previousValue) {

                this.diff = previousValue.diff(value);
                this.isAdditive = diff.second.length != 0;
                this.isSubtractive = diff.first.length != 0;

            }

            /// Check if this entry can be merged with (newer) entry given its text content. This is used to combine
            /// runs of similar actions together, for example when typing a word, the whole word will form a single
            /// entry, instead of creating separate entries per character.
            ///
            /// Two entries can be combined if they are:
            ///
            /// 1. Both additive, and the latter is not subtractive. This combines runs input, including if the first
            ///    item in the run replaces some text. However, replacing text will break an existing chain of actions.
            /// 2. Both subtractive, and neither is additive.
            ///
            /// See_Also: `isAdditive`
            bool canMergeWith(Rope nextValue) const {

                // Create a dummy entry based on the text
                auto nextEntry = HistoryEntry(nextValue, 0, 0);
                nextEntry.setPreviousEntry(value);

                return canMergeWith(nextEntry);

            }

            /// ditto
            bool canMergeWith(HistoryEntry nextEntry) const {

                const mergeAdditive = this.isAdditive
                    && nextEntry.isAdditive
                    && !nextEntry.isSubtractive;

                if (mergeAdditive) return true;

                const mergeSubtractive = !this.isAdditive
                    && this.isSubtractive
                    && !nextEntry.isAdditive
                    && nextEntry.isSubtractive;

                return mergeSubtractive;

            }

        }

        /// If true, current movement action is performed while selecting.
        bool selectionMovement;

        /// Last padding box assigned to this node, with scroll applied.
        Rectangle _inner = Rectangle(0, 0, 0, 0);

        /// If true, the caret index has not changed since last `pushSnapshot`.
        bool _isContinuous;

        /// Current action history, expressed as two stacks, indicating undoable and redoable actions, controllable via
        /// `snapshot`, `pushSnapshot`, `undo` and `redo`.
        DList!HistoryEntry _undoStack;

        /// ditto
        DList!HistoryEntry _redoStack;

    }

    private {

        /// Action used to keep the text input in view.
        ScrollIntoViewAction _scrollAction;

        /// Buffer used to store recently inserted text.
        /// See_Also: `buffer`
        char[] _buffer;

        /// Number of bytes stored in the bufer.
        size_t _usedBufferSize;

        /// Node the buffer is stored in.
        RopeNode* _bufferNode;
        invariant(_bufferNode is null || _bufferNode.left.value.sameTail(_buffer[0 .. _usedBufferSize]),
            "_bufferNode must be in sync with _buffer");

        /// Value of the text input.
        Rope _value;

        /// Available horizontal space.
        float _availableWidth = float.nan;

        /// Visual position of the caret.
        Vector2 _caretPosition;

        /// Index of the caret.
        ptrdiff_t _caretIndex;

        /// Reference point; beginning of selection. Set to -1 if there is no start.
        ptrdiff_t _selectionStart;

        /// Current horizontal visual offset of the label.
        float _scroll = 0;

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
        this.contentLabel = new typeof(contentLabel);

        // Make single line the default
        contentLabel.isWrapDisabled = true;

        // Enable edit mode
        contentLabel.text.hasFastEdits = true;

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

    static class ContentLabel : Label {

        this() {

            super("");

        }

        override bool hoveredImpl(Rectangle, Vector2) const {

            return false;

        }

        override void drawImpl(Rectangle outer, Rectangle inner) {

            // Don't draw background
            const style = pickStyle();
            text.draw(style, inner.start);

        }

        override void reloadStyles() {

            // Do not load styles

        }

        override Style pickStyle() {

            // Always use default style
            return style;

        }

    }

    /// Mark the text input as modified.
    void touch() {

        lastTouch = Clock.currTime;
        scrollIntoView();

    }

    /// Mark the text input as modified and fire the "changed" event.
    void touchText() {

        touch();
        if (changed) changed();

    }

    /// Scroll ancestors so the text input becomes visible.
    ///
    /// `TextInput` keeps its own instance of `ScrollIntoViewAction`, reusing it every time it is needed.
    ///
    /// Params:
    ///     alignToTop = If true, the top of the element will be aligned to the top of the scrollable area.
    ScrollIntoViewAction scrollIntoView(bool alignToTop = false) {

        // Create the action
        if (!_scrollAction) {
            _scrollAction = .scrollIntoView(this, alignToTop);
        }
        else {
            _scrollAction.reset(alignToTop);
            queueAction(_scrollAction);
        }

        return _scrollAction;

    }

    /// Value written in the input.
    inout(Rope) value() inout {

        return _value;

    }

    /// ditto
    Rope value(Rope newValue) {

        auto withoutLineFeeds = Typeface.lineSplitter(newValue).joiner;

        // Single line mode — filter vertical space out
        if (!multiline && !newValue.equal(withoutLineFeeds)) {

            newValue = Typeface.lineSplitter(newValue).join(' ');

        }

        _value = newValue;
        _bufferNode = null;
        updateSize();
        return value;

    }

    /// ditto
    Rope value(const(char)[] value) {

        return this.value(Rope(value));

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

    /// Current horizontal visual offset of the label.
    float scroll() const {

        return _scroll;

    }

    /// Set scroll value.
    float scroll(float value) {

        const limit = max(0, contentLabel.minSize.x - _inner.w);

        return _scroll = value.clamp(0, limit);

    }

    ///
    bool canScroll(Vector2 value) const {

        return clamp(scroll + value.x, 0, _availableWidth) != scroll;

    }

    /// Get the current style for the label.
    /// Params:
    ///     style = Current style of the TextInput.
    Style pickLabelStyle(Style style) {

        // Pick style from the input
        auto result = style;

        // Remove spacing
        result.margin = 0;
        result.padding = 0;
        result.border = 0;

        return result;

    }

    final Style pickLabelStyle() {

        return pickLabelStyle(pickStyle);

    }

    /// Get or set text preceding the caret.
    Rope valueBeforeCaret() const {

        return value[0 .. caretIndex];

    }

    /// ditto
    Rope valueBeforeCaret(Rope newValue) {

        // Replace the data
        if (valueAfterCaret.empty)
            value = newValue;
        else
            value = newValue ~ valueAfterCaret;

        caretIndex = newValue.length;
        updateSize();

        return value[0 .. caretIndex];

    }

    /// ditto
    Rope valueBeforeCaret(const(char)[] newValue) {

        return valueBeforeCaret(Rope(newValue));

    }

    /// Get or set currently selected text.
    Rope selectedValue() inout {

        return value[selectionLowIndex .. selectionHighIndex];

    }

    /// ditto
    Rope selectedValue(Rope newValue) {

        const isLow = caretIndex == selectionStart;
        const low = selectionLowIndex;
        const high = selectionHighIndex;

        value = value.replace(low, high, newValue);
        caretIndex = low + newValue.length;
        updateSize();
        clearSelection();

        return value[low .. low + newValue.length];

    }

    /// ditto
    Rope selectedValue(const(char)[] newValue) {

        return selectedValue(Rope(newValue));

    }

    /// Get or set text following the caret.
    Rope valueAfterCaret() inout {

        return value[caretIndex .. $];

    }

    /// ditto
    Rope valueAfterCaret(Rope newValue) {

        // Replace the data
        if (valueBeforeCaret.empty)
            value = newValue;
        else
            value = valueBeforeCaret ~ newValue;

        updateSize();

        return value[caretIndex .. $];

    }

    /// ditto
    Rope valueAfterCaret(const(char)[] value) {

        return valueAfterCaret(Rope(value));

    }

    unittest {

        auto root = textInput();

        root.value = "hello wörld!";
        assert(root.value == "hello wörld!");

        root.value = "hello wörld!\n";
        assert(root.value == "hello wörld! ");

        root.value = "hello wörld!\r\n";
        assert(root.value == "hello wörld! ");

        root.value = "hello wörld!\v";
        assert(root.value == "hello wörld! ");

    }

    unittest {

        auto root = textInput(.multiline);

        root.value = "hello wörld!";
        assert(root.value == "hello wörld!");

        root.value = "hello wörld!\n";
        assert(root.value == "hello wörld!\n");

        root.value = "hello wörld!\r\n";
        assert(root.value == "hello wörld!\r\n");

        root.value = "hello wörld!\v";
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
        _bufferNode = null;
        _isContinuous = false;
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

    /// Select a part of text. This is preferred to setting `selectionStart` & `selectionEnd` directly, since the two
    /// properties are synchronized together and a change might be ignored.
    void selectSlice(size_t start, size_t end)
    in (end <= value.length, format!"Slice [%s .. %s] exceeds textInput value length of %s"(start, end, value.length))
    do {

        selectionEnd = end;
        selectionStart = start;

    }

    unittest {

        auto root = textInput();
        root.value = "foo bar baz";
        root.selectSlice(0, 3);
        assert(root.selectedValue == "foo");

        root.caretIndex = 4;
        root.selectSlice(4, 7);
        assert(root.selectedValue == "bar");

        root.caretIndex = 11;
        root.selectSlice(8, 11);
        assert(root.selectedValue == "baz");

    }

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

        import std.math : isNaN;

        // Set the size
        minSize = size;

        // Set the label text
        contentLabel.text = value == "" ? placeholder : value;

        const isFill = layout.nodeAlign[0] == NodeAlign.fill;

        _availableWidth = isFill
            ? area.x
            : size.x;

        const textArea = multiline
            ? Vector2(_availableWidth, area.y)
            : Vector2(0, size.y);

        // Resize the label, and remove the spacing
        contentLabel.style = pickLabelStyle(style);
        contentLabel.resize(tree, theme, textArea);

        const minLines = multiline ? 3 : 1;

        // Set height to at least the font size, or total text size
        minSize.y = max(minSize.y, style.getTypeface.lineHeight * minLines, contentLabel.minSize.y);

        // Locate the cursor
        updateCaretPosition();

        // Horizontal anchor is not set, update it
        if (horizontalAnchor.isNaN)
            horizontalAnchor = caretPosition.x;

    }

    unittest {

        auto io = new HeadlessBackend(Vector2(800, 600));
        auto root = textInput(
            .layout!"fill",
            .multiline,
            .nullTheme,
            "This placeholder exceeds the default size of a text input."
        );

        root.io = io;
        root.draw();

        Vector2 textSize() {

            return root.contentLabel.minSize;

        }

        assert(textSize.x > 200);
        assert(textSize.x > root.size.x);

        io.nextFrame;
        root.placeholder = "";
        root.updateSize();
        root.draw();

        assert(root.caretPosition.x < 1);
        assert(textSize.x < 1);

        io.nextFrame;
        root.value = "This value exceeds the default size of a text input.";
        root.updateSize();
        root.caretToEnd();
        root.draw();

        assert(root.caretPosition.x > 200);
        assert(textSize.x > 200);
        assert(textSize.x > root.size.x);

        io.nextFrame;
        root.value = ("This value is long enough to start a new line in the output. To make sure of it, here's "
            ~ "some more text. And more.");
        root.updateSize();
        root.draw();

        assert(textSize.x > root.size.x);
        assert(textSize.x <= 800);
        assert(textSize.y >= root.style.getTypeface.lineHeight * 2);
        assert(root.minSize.y >= textSize.y);

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
        if (_availableWidth.isNaN) {
            _caretPosition.x = float.nan;
            return;
        }

        _caretPosition = caretPositionImpl(_availableWidth, preferNextLine);

        const scrolledCaret = caretPosition.x - scroll;

        // Scroll to make sure the caret is always in view
        const scrollOffset
            = scrolledCaret > _inner.width ? scrolledCaret - _inner.width
            : scrolledCaret < 0            ? scrolledCaret
            : 0;

        // Set the scroll
        scroll = multiline
            ? 0
            : scroll + scrollOffset;

    }

    /// Find the closest index to the given position.
    /// Returns: Index of the character. The index may be equal to character length.
    size_t nearestCharacter(Vector2 needle) {

        import std.math : abs;

        auto ruler = textRuler();
        auto typeface = ruler.typeface;

        struct Position {
            size_t index;
            Vector2 position;
        }

        /// Returns the position (inside the word) of the character that is the closest to the needle.
        Position closest(Vector2 startPosition, Vector2 endPosition, const Rope word) {

            // Needle is before or after the word
            if (needle.x <= startPosition.x) return Position(0, startPosition);
            if (needle.x >= endPosition.x) return Position(word.length, endPosition);

            size_t index;
            auto match = Position(0, startPosition);

            // Search inside the word
            while (index < word.length) {

                decode(word[], index);  // index by reference

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
        search: foreach (index, line; typeface.lineSplitterIndex(value[])) {

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

    /// Get the current buffer.
    ///
    /// The buffer is used to store all content inserted through `push`.
    protected inout(char)[] buffer() inout {

        return _buffer;

    }

    /// Get the used size of the buffer.
    protected ref inout(size_t) usedBufferSize() inout {

        return _usedBufferSize;

    }

    /// Get the filled part of the buffer.
    protected inout(char)[] usedBuffer() inout {

        return _buffer[0 .. _usedBufferSize];

    }

    /// Get the empty part of the buffer.
    protected inout(char)[] freeBuffer() inout {

        return _buffer[_usedBufferSize .. $];

    }

    /// Request a new or a larger buffer.
    /// Params:
    ///     minimumSize = Minimum size to allocate for the buffer.
    protected void newBuffer(size_t minimumSize = 64) {

        const newSize = max(minimumSize, 64);

        _buffer = new char[newSize];
        usedBufferSize = 0;

    }

    protected Vector2 caretPositionImpl(float textWidth, bool preferNextLine) {

        Rope unbreakableChars(Rope value) {

            // Split on lines
            auto lines = Typeface.lineSplitter(value);
            if (lines.empty) return value.init;

            // Split on words
            auto chunks = Typeface.defaultWordChunks(lines.front);
            if (chunks.empty) return value.init;

            // Return empty string if the result starts with whitespace
            if (chunks.front.byDchar.front.isWhite) return value.init;

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
            : Rope.init;

        auto typeface = style.getTypeface;
        auto ruler = textRuler();
        auto slice = value[0 .. caretIndex + tail.length];

        // Measure text until the caret; include the word that follows to keep proper wrapping
        typeface.measure(ruler, slice, multiline);

        auto caretPosition = ruler.caret.start;

        // Measure the word itself, and remove it
        caretPosition.x -= typeface.measure(tail[]).x;

        return caretPosition;

    }

    protected override void drawImpl(Rectangle outer, Rectangle inner) @trusted {

        auto style = pickStyle();

        // Fill the background
        style.drawBackground(tree.io, outer);

        // Copy style to the label
        contentLabel.style = pickLabelStyle(style);

        // Scroll the inner rectangle
        auto scrolledInner = inner;
        scrolledInner.x -= scroll;

        // Save the inner box
        _inner = scrolledInner;

        // Increase the size of the inner box so that tree doesn't turn on scissors mode on its own
        scrolledInner.w += scroll;

        const lastScissors = tree.pushScissors(outer);
        scope (exit) tree.popScissors(lastScissors);

        // Draw the contents
        drawContents(inner, scrolledInner);

    }

    protected void drawContents(Rectangle inner, Rectangle scrolledInner) {

        // Draw selection
        drawSelection(scrolledInner);

        // Draw the text
        contentLabel.draw(scrolledInner);

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

    override Rectangle focusBoxImpl(Rectangle inner) const {

        const lineHeight = style.getTypeface.lineHeight;
        const position = inner.start + caretPosition;

        return Rectangle(
            position.tupleof,
            1, lineHeight
        );

    }

    /// Get an appropriate text ruler for this input.
    protected TextRuler textRuler() {

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

    protected override bool keyboardImpl() {

        import std.uni : isAlpha, isWhite;
        import std.range : back;

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
            touchText();

            return true;

        }

        return true;

    }

    unittest {

        auto root = textInput();
        root.value = "Ho";

        root.caretIndex = 1;
        root.push("e");
        assert(root.value.byNode.equal(["H", "e", "o"]));

        root.push("n");

        assert(root.value.byNode.equal(["H", "en", "o"]));

        root.push("l");
        assert(root.value.byNode.equal(["H", "enl", "o"]));

        // Create enough text to fill the buffer
        // A new node should be created as a result
        auto bufferFiller = 'A'.repeat(root.freeBuffer.length).array;

        root.push(bufferFiller);
        assert(root.value.byNode.equal(["H", "enl", bufferFiller, "o"]));

        // Undo all pushes until the initial fill
        root.undo();
        assert(root.value == "Ho");
        assert(root.valueBeforeCaret == "H");

        // Undo will not clear the initial value
        root.undo();
        assert(root.value == "Ho");
        assert(root.valueBeforeCaret == "H");

        // The above undo does not add a new redo stack entry; effectively, this redo cancels both undo actions above
        root.redo();
        assert(root.value.byNode.equal(["H", "enl", bufferFiller, "o"]));

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

        // The text will be displayed the next frame
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
    void push(scope const(char)[] ch)
    out (; _bufferNode, "_bufferNode must exist after pushing to buffer")
    do {

        // Move the buffer node into here; move it back when done
        auto bufferNode = _bufferNode;
        _bufferNode = null;
        scope (exit) _bufferNode = bufferNode;

        // Not enough space in the buffer, allocate more
        if (freeBuffer.length <= ch.length) {

            newBuffer(ch.length);
            bufferNode = null;

        }

        auto slice = freeBuffer[0 .. ch.length];

        // Save the data in the buffer
        slice[] = ch;
        _usedBufferSize += ch.length;

        // Selection is active, overwrite it
        if (isSelecting) {

            bufferNode = new RopeNode(Rope(slice), Rope.init);
            push(Rope(bufferNode));
            return;

        }

        // The above `if` handles the one case where `push` doesn't directly add new characters to the text.
        // From here, appending can be optimized by memorizing the node we create to add the text, and reusing it
        // afterwards. This way, we avoid creating many one element nodes.

        size_t originalLength;

        // Make sure there is a node to write to
        if (!bufferNode)
            bufferNode = new RopeNode(Rope(slice), Rope.init);

        // If writing in a single sequence, reuse the last inserted node
        else {

            originalLength = bufferNode.length;

            // Append the character to its value
            // The bufferNode will always share tail with the buffer
            bufferNode.left = usedBuffer[$ - originalLength - ch.length .. $];

        }

        // Save previous value in undo stack
        const previousState = snapshot();
        scope (success) pushSnapshot(previousState);

        // Insert the text by replacing the old node, if present
        value = value.replace(caretIndex - originalLength, caretIndex, Rope(bufferNode));
        assert(value.isBalanced);

        // Move the caret
        caretIndex = caretIndex + ch.length;
        updateCaretPosition();
        horizontalAnchor = caretPosition.x;

    }

    /// ditto
    void push(Rope text) {

        // Save previous value in undo stack
        const previousState = snapshot();
        scope (success) pushSnapshot(previousState);

        // If selection is active, overwrite the selection
        if (isSelecting) {

            // Override with the character
            selectedValue = text;
            clearSelection();

        }

        // Insert the character before caret
        else if (valueBeforeCaret.length) {

            valueBeforeCaret = valueBeforeCaret ~ text;
            touch();

        }

        else {

            valueBeforeCaret = text;
            touch();

        }

        updateCaretPosition();
        horizontalAnchor = caretPosition.x;

    }

    /// Start a new line
    @(FluidInputAction.breakLine)
    protected bool breakLine() {

        if (!multiline) return false;

        auto snap = snapshot();
        push('\n');
        forcePushSnapshot(snap);

        return true;

    }

    unittest {

        auto root = textInput();

        root.push("hello");
        root.runInputAction!(FluidInputAction.breakLine);

        assert(root.value == "hello");

    }

    unittest {

        auto root = textInput(.multiline);

        root.push("hello");
        root.runInputAction!(FluidInputAction.breakLine);
        assert(root.value == "hello\n");

        root.undo();
        assert(root.value == "hello");
        root.redo();
        assert(root.value == "hello\n");

        root.undo();
        assert(root.value == "hello");
        root.undo();
        assert(root.value == "");
        root.redo();
        assert(root.value == "hello");
        root.redo();
        assert(root.value == "hello\n");

    }

    unittest {

        auto root = textInput(.nullTheme, .multiline);

        root.push("Привет, мир!");
        root.runInputAction!(FluidInputAction.breakLine);

        assert(root.value == "Привет, мир!\n");
        assert(root.caretIndex == root.value.length);

        root.push("Это пример текста для тестирования поддержки Unicode во Fluid.");
        root.runInputAction!(FluidInputAction.breakLine);

        assert(root.value == "Привет, мир!\nЭто пример текста для тестирования поддержки Unicode во Fluid.\n");
        assert(root.caretIndex == root.value.length);

    }

    unittest {

        auto root = textInput(.multiline);
        root.push("first line");
        root.breakLine();
        root.push("second line");
        root.breakLine();
        assert(root.value == "first line\nsecond line\n");

        root.undo();
        assert(root.value == "first line\nsecond line");
        root.undo();
        assert(root.value == "first line\n");
        root.undo();
        assert(root.value == "first line");
        root.undo();
        assert(root.value == "");
        root.redo();
        assert(root.value == "first line");
        root.redo();
        assert(root.value == "first line\n");
        root.redo();
        assert(root.value == "first line\nsecond line");
        root.redo();
        assert(root.value == "first line\nsecond line\n");

    }

    /// Submit the input.
    @(FluidInputAction.submit)
    void submit() {

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
        root.push("Hello, World!");

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
        version (OSX)
            io.press(KeyboardKey.leftCommand);
        else 
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

        // Save previous value in undo stack
        const previousState = snapshot();
        scope (success) pushSnapshot(previousState);

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

    unittest {

        auto root = textInput();

        root.push("Это пример текста для тестирования поддержки Unicode во Fluid.");
        root.chopWord;
        assert(root.value == "Это пример текста для тестирования поддержки Unicode во Fluid");

        root.chopWord;
        assert(root.value == "Это пример текста для тестирования поддержки Unicode во ");

        root.chopWord;
        assert(root.value == "Это пример текста для тестирования поддержки Unicode ");

        root.chopWord;
        assert(root.value == "Это пример текста для тестирования поддержки ");

        root.chopWord;
        assert(root.value == "Это пример текста для тестирования ");

        root.caretToStart();
        root.chopWord(true);
        assert(root.value == "пример текста для тестирования ");

        root.chopWord(true);
        assert(root.value == "текста для тестирования ");

    }

    /// Remove a word before the caret.
    @(FluidInputAction.backspaceWord)
    void backspaceWord() {

        chopWord();
        touchText();

    }

    unittest {

        auto io = new HeadlessBackend;
        auto root = textInput();

        root.io = io;

        // Type stuff
        {
            root.value = "Hello World";
            root.focus();
            root.caretToEnd();
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

    /// Delete a word in front of the caret.
    @(FluidInputAction.deleteWord)
    void deleteWord() {

        chopWord(true);
        touchText();

    }

    unittest {

        auto root = textInput();

        // deleteWord should do nothing, because the caret is at the end
        root.push("Hello, Wörld");
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

        // Save previous value in undo stack
        const previousState = snapshot();
        scope (success) pushSnapshot(previousState);

        // Selection active
        if (isSelecting) {

            selectedValue = null;

        }

        // Remove next character
        else if (forward) {

            if (valueAfterCaret == "") return;

            const length = valueAfterCaret.decodeFrontStatic.codeLength!char;

            valueAfterCaret = valueAfterCaret[length..$];

        }

        // Remove previous character
        else {

            if (valueBeforeCaret == "") return;

            const length = valueBeforeCaret.decodeBackStatic.codeLength!char;

            valueBeforeCaret = valueBeforeCaret[0..$-length];

        }

        // Trigger the callback
        touchText();

        // Update the size of the box
        updateSize();
        updateCaretPosition();
        horizontalAnchor = caretPosition.x;

    }

    unittest {

        auto root = textInput();

        root.push("поддержки во Fluid.");
        root.chop;
        assert(root.value == "поддержки во Fluid");

        root.chop;
        assert(root.value == "поддержки во Flui");

        root.chop;
        assert(root.value == "поддержки во Flu");

        root.chopWord;
        assert(root.value == "поддержки во ");

        root.chop;
        assert(root.value == "поддержки во");

        root.chop;
        assert(root.value == "поддержки в");

        root.chop;
        assert(root.value == "поддержки ");

        root.caretToStart();
        root.chop(true);
        assert(root.value == "оддержки ");

        root.chop(true);
        assert(root.value == "ддержки ");

        root.chop(true);
        assert(root.value == "держки ");

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

            // Second click, select the word surrounding the caret
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
        root.value = "Hello, World! Foo, bar, scroll this input";
        root.focus();
        root.caretToEnd();
        root.draw();

        assert(root.scroll.isClose(127));

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
        root.value = "Hello, World! Foo, bar, scroll this input";
        root.focus();
        root.caretToEnd();
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
        root.value = "Line one\nLine two\n\nLine four";
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

    protected override void scrollImpl(Vector2 value) {

        const speed = ScrollInput.scrollSpeed;
        const move = speed * value.x;

        scroll = scroll + move;

    }

    Rectangle shallowScrollTo(const(Node) child, Rectangle parentBox, Rectangle childBox) {

        return childBox;

    }

    /// Get line in the input by a byte index.
    /// Returns: A rope slice with the line containing the given index.
    Rope lineByIndex(KeepTerminator keepTerminator = No.keepTerminator)(size_t index) const {

        return value.lineByIndex!keepTerminator(index);

    }

    /// Update a line with given byte index.
    const(char)[] lineByIndex(size_t index, const(char)[] value) {

        lineByIndex(index, Rope(value));
        return value;

    }

    /// ditto
    Rope lineByIndex(size_t index, Rope newValue) {

        import std.utf;
        import fluid.typeface;

        const backLength = Typeface.lineSplitter(value[0..index].retro).front.byChar.walkLength;
        const frontLength = Typeface.lineSplitter(value[index..$]).front.byChar.walkLength;
        const start = index - backLength;
        const end = index + frontLength;
        size_t[2] selection = [selectionStart, selectionEnd];

        // Combine everything on the same line, before and after the caret
        value = value.replace(start, end, newValue);

        // Caret/selection needs updating
        foreach (i, ref caret; selection) {

            const diff = newValue.length - end + start;

            if (caret < start) continue;

            // Move the caret to the start or end, depending on its type
            if (caret <= end) {

                // Selection start moves to the beginning
                // But only if selection is active
                if (i == 0 && isSelecting)
                    caret = start;

                // End moves to the end
                else
                    caret = start + newValue.length;

            }

            // Offset the caret
            else caret += diff;

        }

        // Update the carets
        selectionStart = selection[0];
        selectionEnd = selection[1];

        return newValue;

    }

    unittest {

        auto root = textInput(.multiline);
        root.push("foo");
        root.lineByIndex(0, "foobar");
        assert(root.value == "foobar");
        assert(root.valueBeforeCaret == "foobar");

        root.push("\nąąąźź");
        root.lineByIndex(6, "~");
        root.caretIndex = root.caretIndex - 2;
        assert(root.value == "~\nąąąźź");
        assert(root.valueBeforeCaret == "~\nąąąź");

        root.push("\n\nstuff");
        assert(root.value == "~\nąąąź\n\nstuffź");

        root.lineByIndex(11, "");
        assert(root.value == "~\nąąąź\n\nstuffź");

        root.lineByIndex(11, "*");
        assert(root.value == "~\nąąąź\n*\nstuffź");

    }

    unittest {

        auto root = textInput(.multiline);
        root.push("óne\nßwo\nßhree");
        root.selectionStart = 5;
        root.selectionEnd = 14;
        root.lineByIndex(5, "[REDACTED]");
        assert(root.value[root.selectionEnd] == 'e');
        assert(root.value == "óne\n[REDACTED]\nßhree");

        assert(root.value[root.selectionEnd] == 'e');
        assert(root.selectionStart == 5);
        assert(root.selectionEnd == 20);

    }

    /// Get the index of the start or end of the line — from index of any character on the same line.
    size_t lineStartByIndex(size_t index) {

        return value.lineStartByIndex(index);

    }

    /// ditto
    size_t lineEndByIndex(size_t index) {

        return value.lineEndByIndex(index);

    }

    /// Get the current line
    Rope caretLine() {

        return value.lineByIndex(caretIndex);

    }

    unittest {

        auto root = textInput(.multiline);
        assert(root.caretLine == "");
        root.push("aąaa");
        assert(root.caretLine == root.value);
        root.caretIndex = 0;
        assert(root.caretLine == root.value);
        root.push("bbb");
        assert(root.caretLine == root.value);
        assert(root.value == "bbbaąaa");
        root.push("\n");
        assert(root.value == "bbb\naąaa");
        assert(root.caretLine == "aąaa");
        root.caretToEnd();
        root.push("xx");
        assert(root.caretLine == "aąaaxx");
        root.push("\n");
        assert(root.caretLine == "");
        root.push("\n");
        assert(root.caretLine == "");
        root.caretIndex = root.caretIndex - 1;
        assert(root.caretLine == "");
        root.caretToStart();
        assert(root.caretLine == "bbb");

    }

    /// Change the current line. Moves the cursor to the end of the newly created line.
    const(char)[] caretLine(const(char)[] newValue) {

        return lineByIndex(caretIndex, newValue);

    }

    /// ditto
    Rope caretLine(Rope newValue) {

        return lineByIndex(caretIndex, newValue);

    }

    unittest {

        auto root = textInput(.multiline);
        root.push("a\nbb\nccc\n");
        assert(root.caretLine == "");

        root.caretIndex = root.caretIndex - 1;
        assert(root.caretLine == "ccc");

        root.caretLine = "hi";
        assert(root.value == "a\nbb\nhi\n");

        assert(!root.isSelecting);
        assert(root.valueBeforeCaret == "a\nbb\nhi");

        root.caretLine = "";
        assert(root.value == "a\nbb\n\n");
        assert(root.valueBeforeCaret == "a\nbb\n");

        root.caretLine = "new value";
        assert(root.value == "a\nbb\nnew value\n");
        assert(root.valueBeforeCaret == "a\nbb\nnew value");

        root.caretIndex = 0;
        root.caretLine = "insert";
        assert(root.value == "insert\nbb\nnew value\n");
        assert(root.valueBeforeCaret == "insert");
        assert(root.caretLine == "insert");

    }

    /// Get the column the given index (or the cursor, if omitted) is on.
    /// Returns:
    ///     Return value depends on the type fed into the function. `column!dchar` will use characters and `column!char`
    ///     will use bytes. The type does not have effect on the input index.
    ptrdiff_t column(Chartype)(ptrdiff_t index) {

        return value.column!Chartype(index);

    }

    /// ditto
    ptrdiff_t column(Chartype)() {

        return column!Chartype(caretIndex);

    }

    unittest {

        auto root = textInput(.multiline);
        assert(root.column!dchar == 0);
        root.push(" ");
        assert(root.column!dchar == 1);
        root.push("a");
        assert(root.column!dchar == 2);
        root.push("ąąą");
        assert(root.column!dchar == 5);
        assert(root.column!char == 8);
        root.push("O\n");
        assert(root.column!dchar == 0);
        root.push(" ");
        assert(root.column!dchar == 1);
        root.push("HHH");
        assert(root.column!dchar == 4);

    }

    /// Iterate on each line in an interval.
    auto eachLineByIndex(ptrdiff_t start, ptrdiff_t end) {

        struct LineIterator {

            TextInput input;
            ptrdiff_t index;
            ptrdiff_t end;

            private Rope front;
            private ptrdiff_t nextLine;

            alias SetLine = void delegate(Rope line) @safe;

            int opApply(scope int delegate(size_t startIndex, ref Rope line) @safe yield) {

                while (index <= end) {

                    const line = input.value.lineByIndex!(Yes.keepTerminator)(index);

                    // Get index of the next line
                    const lineStart = index - input.column!char(index);
                    nextLine = lineStart + line.length;

                    // Output the line
                    const originalFront = front = line[].chomp;
                    auto stop = yield(lineStart, front);

                    // Update indices in case the line has changed
                    if (front !is originalFront) {
                        setLine(originalFront, front);
                    }

                    // Stop if requested
                    if (stop) return stop;

                    // Stop if reached the end of string
                    if (index == nextLine) return 0;
                    if (line.length == originalFront.length) return 0;

                    // Move to the next line
                    index = nextLine;

                }

                return 0;

            }

            int opApply(scope int delegate(ref Rope line) @safe yield) {

                foreach (index, ref line; this) {

                    if (auto stop = yield(line)) return stop;

                }

                return 0;

            }

            /// Replace the current line with a new one.
            private void setLine(Rope oldLine, Rope line) @safe {

                const lineStart = index - input.column!char(index);

                // Get the size of the line terminator
                const lineTerminatorLength = nextLine - lineStart - oldLine.length;

                // Update the line
                input.lineByIndex(index, line);
                index = lineStart + line.length;
                end += line.length - oldLine.length;

                // Add the terminator
                nextLine = index + lineTerminatorLength;

                assert(line == front);
                assert(nextLine >= index);
                assert(nextLine <= input.value.length);

            }

        }

        return LineIterator(this, start, end);

    }

    unittest {

        auto root = textInput(.multiline);
        root.push("aaaąąą@\r\n#\n##ąąśðą\nĄŚ®ŒĘ¥Ę®\n");

        size_t i;
        foreach (line; root.eachLineByIndex(4, 18)) {

            if (i == 0) assert(line == "aaaąąą@");
            if (i == 1) assert(line == "#");
            if (i == 2) assert(line == "##ąąśðą");
            assert(i.among(0, 1, 2));
            i++;

        }
        assert(i == 3);

        i = 0;
        foreach (line; root.eachLineByIndex(22, 27)) {

            if (i == 0) assert(line == "##ąąśðą");
            if (i == 1) assert(line == "ĄŚ®ŒĘ¥Ę®");
            assert(i.among(0, 1));
            i++;

        }
        assert(i == 2);

        i = 0;
        foreach (line; root.eachLineByIndex(44, 44)) {

            assert(i == 0);
            assert(line == "");
            i++;

        }
        assert(i == 1);

        i = 0;
        foreach (line; root.eachLineByIndex(1, 1)) {

            assert(i == 0);
            assert(line == "aaaąąą@");
            i++;

        }
        assert(i == 1);

    }

    unittest {

        auto root = textInput(.multiline);
        root.push("skip\nonë\r\ntwo\r\nthree\n");

        assert(root.lineByIndex(4) == "skip");
        assert(root.lineByIndex(8) == "onë");
        assert(root.lineByIndex(12) == "two");

        size_t i;
        foreach (lineStart, ref line; root.eachLineByIndex(5, root.value.length)) {

            if (i == 0) {
                assert(line == "onë");
                assert(lineStart == 5);
                line = Rope("value");
            }
            else if (i == 1) {
                assert(root.value == "skip\nvalue\r\ntwo\r\nthree\n");
                assert(lineStart == 12);
                assert(line == "two");
                line = Rope("\nbar-bar-bar-bar-bar");
            }
            else if (i == 2) {
                assert(root.value == "skip\nvalue\r\n\nbar-bar-bar-bar-bar\r\nthree\n");
                assert(lineStart == 34);
                assert(line == "three");
                line = Rope.init;
            }
            else if (i == 3) {
                assert(root.value == "skip\nvalue\r\n\nbar-bar-bar-bar-bar\r\n\n");
                assert(lineStart == root.value.length);
                assert(line == "");
            }
            else assert(false);

            i++;

        }

        assert(i == 4);

    }

    unittest {

        auto root = textInput(.multiline);
        root.push("Fïrst line\nSëcond line\r\n Third line\n    Fourth line\rFifth line");

        size_t i = 0;
        foreach (ref line; root.eachLineByIndex(19, 49)) {

            if (i == 0) assert(line == "Sëcond line");
            else if (i == 1) assert(line == " Third line");
            else if (i == 2) assert(line == "    Fourth line");
            else assert(false);
            i++;

            line = "    " ~ line;

        }
        assert(i == 3);
        root.selectionStart = 19;
        root.selectionEnd = 49;

    }

    unittest {

        auto root = textInput();
        root.value = "some text, some line, some stuff\ntext";

        foreach (ref line; root.eachLineByIndex(root.value.length, root.value.length)) {

            line = Rope("");
            line = Rope("woo");
            line = Rope("n");
            line = Rope(" ąąą ");
            line = Rope("");

        }

        assert(root.value == "");

    }

    unittest {

        auto root = textInput();
        root.value = "test";

        {
            size_t i;
            foreach (line; root.eachLineByIndex(1, 4)) {

                assert(i++ == 0);
                assert(line == "test");

            }
        }

        {
            size_t i;
            foreach (ref line; root.eachLineByIndex(1, 4)) {

                assert(i++ == 0);
                assert(line == "test");
                line = "tested";

            }
            assert(root.value == "tested");
        }

    }

    /// Return each line containing the selection.
    auto eachSelectedLine() {

        return eachLineByIndex(selectionLowIndex, selectionHighIndex);

    }

    unittest {

        auto root = textInput();

        foreach (ref line; root.eachSelectedLine) {

            line = Rope("value");

        }

        assert(root.value == "value");

    }

    /// Open the input's context menu.
    @(FluidInputAction.contextMenu)
    void openContextMenu() {

        // Move the caret
        if (!isSelecting)
            caretToMouse();

        // Spawn the popup
        tree.spawnPopup(contextMenu);

        // Anchor to caret position
        contextMenu.anchor = _inner.start + caretPosition;

    }

    /// Remove a character before the caret. Same as `chop`.
    @(FluidInputAction.backspace)
    void backspace() {

        chop();

    }

    /// Delete one character in front of the cursor.
    @(FluidInputAction.deleteChar)
    void deleteChar() {

        chop(true);

    }

    unittest {

        auto io = new HeadlessBackend;
        auto root = textInput();

        root.io = io;

        // Type stuff
        {
            root.value = "hello‽";
            root.focus();
            root.caretToEnd();
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
        value = null;

        clearSelection();
        updateCaretPosition();
        horizontalAnchor = caretPosition.x;

    }

    unittest {

        auto io = new HeadlessBackend;
        auto root = textInput();

        io.inputCharacter("Hello, World!");
        root.io = io;
        root.focus();
        root.draw();

        auto value1 = root.value;

        root.chop();

        assert(root.value == "Hello, World");

        auto value2 = root.value;
        root.chopWord();

        assert(root.value == "Hello, ");

        auto value3 = root.value;
        root.clear();

        assert(root.value == "");

    }

    unittest {

        auto io = new HeadlessBackend;
        auto root = textInput();

        io.inputCharacter("Hello, World");
        root.io = io;
        root.focus();
        root.draw();

        auto value1 = root.value;

        root.chopWord();

        assert(root.value == "Hello, ");

        auto value2 = root.value;

        root.push("Moon");

        assert(root.value == "Hello, Moon");

        auto value3 = root.value;

        root.clear();

        assert(root.value == "");

    }

    /// Select the word surrounding the cursor. If selection is active, expands selection to cover words.
    void selectWord() {

        enum excludeWhite = true;

        const isLow = selectionStart <= selectionEnd;
        const low = selectionLowIndex;
        const high = selectionHighIndex;

        const head = value[0 .. low].wordBack(excludeWhite);
        const tail = value[high .. $].wordFront(excludeWhite);

        // Move the caret to the end of the word
        caretIndex = high + tail.length;

        // Set selection to the start of the word
        selectionStart = low - head.length;

        // Swap them if order is reversed
        if (!isLow) swap(_selectionStart, _caretIndex);

        touch();
        updateCaretPosition(false);

    }

    unittest {

        auto root = textInput();
        root.push("Привет, мир! Это пример текста для тестирования поддержки Unicode во Fluid.");

        // Select word the caret is touching
        root.selectWord();
        assert(root.selectedValue == ".");

        // Expand
        root.selectWord();
        assert(root.selectedValue == "Fluid.");

        // Go to start
        root.caretToStart();
        assert(!root.isSelecting);
        assert(root.caretIndex == 0);
        assert(root.selectedValue == "");

        root.selectWord();
        assert(root.selectedValue == "Привет");

        root.selectWord();
        assert(root.selectedValue == "Привет,");

        root.selectWord();
        assert(root.selectedValue == "Привет,");

        root.runInputAction!(FluidInputAction.nextChar);
        assert(root.caretIndex == 13);  // Before space

        root.runInputAction!(FluidInputAction.nextChar);  // After space
        root.runInputAction!(FluidInputAction.nextChar);  // Inside "мир"
        assert(!root.isSelecting);
        assert(root.caretIndex == 16);

        root.selectWord();
        assert(root.selectedValue == "мир");

        root.selectWord();
        assert(root.selectedValue == "мир!");

    }

    /// Select the whole line the cursor is.
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
        horizontalAnchor = caretPosition.x;

    }

    unittest {

        auto root = textInput();

        root.push("ąąąą ąąą ąąąąąąą ąą\nąąą ąąą");
        assert(root.caretIndex == 49);

        root.selectLine();
        assert(root.selectedValue == root.value);
        assert(root.selectedValue.length == 49);
        assert(root.value.length == 49);

    }

    unittest {

        auto root = textInput(.multiline);

        root.push("ąąą ąąą ąąąąąąą ąą\nąąą ąąą");
        root.draw();
        assert(root.caretIndex == 47);

        root.selectLine();
        assert(root.selectedValue == "ąąą ąąą");
        assert(root.selectionStart == 34);
        assert(root.selectionEnd == 47);

        root.runInputAction!(FluidInputAction.selectPreviousLine);
        assert(root.selectionStart == 34);
        assert(root.selectionEnd == 13);
        assert(root.selectedValue == " ąąąąąąą ąą\n");

        root.selectLine();
        assert(root.selectedValue == root.value);

    }

    /// Move caret to the previous or next character.
    @(FluidInputAction.previousChar, FluidInputAction.nextChar)
    protected void previousOrNextChar(FluidInputAction action) {

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

            const length = valueAfterCaret.decodeFrontStatic.codeLength!char;

            caretIndex = caretIndex + length;

        }

        // Move to previous character
        else {

            if (valueBeforeCaret == "") return;

            const length = valueBeforeCaret.decodeBackStatic.codeLength!char;

            caretIndex = caretIndex - length;

        }

        updateCaretPosition(true);
        horizontalAnchor = caretPosition.x;

    }

    unittest {

        auto root = textInput();
        root.push("Привет, мир! Это пример текста для тестирования поддержки Unicode во Fluid.");

        assert(root.caretIndex == root.value.length);

        root.runInputAction!(FluidInputAction.previousWord);
        assert(root.caretIndex == root.value.length - ".".length);

        root.runInputAction!(FluidInputAction.previousWord);
        assert(root.caretIndex == root.value.length - "Fluid.".length);

        root.runInputAction!(FluidInputAction.previousChar);
        assert(root.caretIndex == root.value.length - " Fluid.".length);

        root.runInputAction!(FluidInputAction.previousChar);
        assert(root.caretIndex == root.value.length - "о Fluid.".length);

        root.runInputAction!(FluidInputAction.previousChar);
        assert(root.caretIndex == root.value.length - "во Fluid.".length);

        root.runInputAction!(FluidInputAction.previousWord);
        assert(root.caretIndex == root.value.length - "Unicode во Fluid.".length);

        root.runInputAction!(FluidInputAction.previousWord);
        assert(root.caretIndex == root.value.length - "поддержки Unicode во Fluid.".length);

        root.runInputAction!(FluidInputAction.nextChar);
        assert(root.caretIndex == root.value.length - "оддержки Unicode во Fluid.".length);

        root.runInputAction!(FluidInputAction.nextWord);
        assert(root.caretIndex == root.value.length - "Unicode во Fluid.".length);

    }

    /// Move caret to the previous or next word.
    @(FluidInputAction.previousWord, FluidInputAction.nextWord)
    protected void previousOrNextWord(FluidInputAction action) {

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
    protected void previousOrNextLine(FluidInputAction action) {

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

    unittest {

        auto root = textInput(.multiline);

        // 5 en dashes, 3 then 4; starting at last line
        root.push("–––––\n–––\n––––");
        root.draw();

        assert(root.caretIndex == root.value.length);

        // From last line to second line — caret should be at its end
        root.runInputAction!(FluidInputAction.previousLine);
        assert(root.valueBeforeCaret == "–––––\n–––");

        // First line, move to 4th dash (same as third line)
        root.runInputAction!(FluidInputAction.previousLine);
        assert(root.valueBeforeCaret == "––––");

        // Next line — end
        root.runInputAction!(FluidInputAction.nextLine);
        assert(root.valueBeforeCaret == "–––––\n–––");

        // Update anchor to match second line
        root.runInputAction!(FluidInputAction.toLineEnd);
        assert(root.valueBeforeCaret == "–––––\n–––");

        // First line again, should be 3rd dash now (same as second line)
        root.runInputAction!(FluidInputAction.previousLine);
        assert(root.valueBeforeCaret == "–––");

        // Last line, 3rd dash too
        root.runInputAction!(FluidInputAction.nextLine);
        root.runInputAction!(FluidInputAction.nextLine);
        assert(root.valueBeforeCaret == "–––––\n–––\n–––");

    }

    /// Move the caret to the given screen position (viewport space).
    /// Params:
    ///     position = Position in the screen to move the cursor to.
    void caretTo(Vector2 position) {

        caretIndex = nearestCharacter(position);

    }

    @("TextInput.caretTo works")
    unittest {

        // Note: This test depends on parameters specific to the default typeface.

        import std.math : isClose;

        auto io = new HeadlessBackend;
        auto root = textInput(.nullTheme, .multiline);

        root.io = io;
        root.size = Vector2(200, 0);
        root.value = "Hello, World!\nHello, Moon\n\nHello, Sun\nWrap this line µp, make it long enough to cross over";
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
        root.value = "123\n456\n789";
        root.draw();

        io.nextFrame();
        io.mousePosition = Vector2(140, 90);
        root.caretToMouse();

        assert(root.caretIndex == 3);

    }

    /// Move the caret to the beginning of the line. This function perceives the line visually, so if the text wraps, it
    /// will go to the beginning of the visible line, instead of the hard line break.
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
        root.value = "Hello, World!\nHello, Moon\n\nHello, Sun\nWrap this line µp, make it long enough to cross over";
        root.focus();
        root.draw();

        root.caretIndex = 0;
        root.updateCaretPosition();
        root.runInputAction!(FluidInputAction.toLineEnd);

        assert(root.caretIndex == "Hello, World!".length);

        // Move to the next line, should be at the end
        root.runInputAction!(FluidInputAction.nextLine);

        assert(root.valueBeforeCaret.wordBack == "Moon");
        assert(root.valueAfterCaret.wordFront == "\n");

        // Move to the blank line
        root.runInputAction!(FluidInputAction.nextLine);

        const blankLine = root.caretIndex;
        assert(root.valueBeforeCaret.wordBack == "\n");
        assert(root.valueAfterCaret.wordFront == "\n");

        // toLineEnd and toLineStart should have no effect
        root.runInputAction!(FluidInputAction.toLineStart);
        assert(root.caretIndex == blankLine);
        root.runInputAction!(FluidInputAction.toLineEnd);
        assert(root.caretIndex == blankLine);

        // Next line again
        // The anchor has been reset to the beginning
        root.runInputAction!(FluidInputAction.nextLine);

        assert(root.valueBeforeCaret.wordBack == "\n");
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

        root.push("foo bar ");

        assert(!root.isSelecting);

        root.push("baz");

        assert(root.value == "foo bar baz");

        auto value1 = root.value;

        root.selectAll();

        assert(root.selectionStart == 0);
        assert(root.selectionEnd == root.value.length);

        root.push("replaced");

        assert(root.value == "replaced");

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
    protected void select(FluidInputAction action) {

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
    void cut() {

        auto snap = snapshot();
        copy();
        pushSnapshot(snap);
        selectedValue = null;

    }

    unittest {

        auto root = textInput();

        root.draw();
        root.push("Foo Bar Baz Ban");

        // Move cursor to "Bar"
        root.runInputAction!(FluidInputAction.toStart);
        root.runInputAction!(FluidInputAction.nextWord);

        // Select "Bar Baz "
        root.runInputAction!(FluidInputAction.selectNextWord);
        root.runInputAction!(FluidInputAction.selectNextWord);

        assert(root.io.clipboard == "");
        assert(root.selectedValue == "Bar Baz ");

        // Cut the text
        root.cut();

        assert(root.io.clipboard == "Bar Baz ");
        assert(root.value == "Foo Ban");

    }

    unittest {

        auto root = textInput();

        root.push("Привет, мир! Это пример текста для тестирования поддержки Unicode во Fluid.");
        root.draw();
        root.io.clipboard = "ą";

        root.runInputAction!(FluidInputAction.previousChar);
        root.selectionStart = 106;  // Before "Unicode"
        root.cut();

        assert(root.value == "Привет, мир! Это пример текста для тестирования поддержки .");
        assert(root.io.clipboard == "Unicode во Fluid");

        root.caretIndex = 14;
        root.runInputAction!(FluidInputAction.selectNextWord);  // мир
        root.paste();

        assert(root.value == "Привет, Unicode во Fluid! Это пример текста для тестирования поддержки .");

    }

    /// Copy selected text to clipboard.
    @(FluidInputAction.copy)
    void copy() {

        import std.conv : text;

        if (isSelecting)
            io.clipboard = text(selectedValue);

    }

    unittest {

        auto root = textInput();

        root.draw();
        root.push("Foo Bar Baz Ban");

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
    void paste() {

        auto snap = snapshot();
        push(io.clipboard);
        forcePushSnapshot(snap);

    }

    unittest {

        auto root = textInput();

        root.value = "Foo ";
        root.draw();
        root.caretToEnd();
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

    /// Clear the undo/redo action history.
    ///
    /// Calling this will erase both the undo and redo stack, making it impossible to restore any changes made in prior,
    /// through means such as Ctrl+Z and Ctrl+Y.
    void clearHistory() {

        _undoStack.clear();
        _redoStack.clear();

    }

    /// Push the given state snapshot (value, caret & selection) into the undo stack. Refuses to push if the current
    /// state can be merged with it, unless `forcePushSnapshot` is used.
    ///
    /// A snapshot pushed through `forcePushSnapshot` will break continuity — it will not be merged with any other
    /// snapshot.
    void pushSnapshot(HistoryEntry entry) {

        // Compare against current state, so it can be dismissed if it's too similar
        auto currentState = snapshot();
        currentState.setPreviousEntry(entry);

        // Mark as continuous, so runs of similar characters can be merged together
        scope (success) _isContinuous = true;

        // No change was made, ignore
        if (currentState.diff.isSame()) return;

        // Current state is compatible, ignore
        if (entry.isContinuous && entry.canMergeWith(currentState)) return;

        // Push state
        forcePushSnapshot(entry);

    }

    /// ditto
    void forcePushSnapshot(HistoryEntry entry) {

        // Break continuity
        _isContinuous = false;

        // Ignore if the last entry is identical
        if (!_undoStack.empty && _undoStack.back == entry) return;

        // Truncate the history to match the index, insert the current value.
        _undoStack.insertBack(entry);

        // Clear the redo stack
        _redoStack.clear();

    }

    unittest {

        auto root = textInput(.multiline);
        root.push("Hello, ");
        root.runInputAction!(FluidInputAction.breakLine);
        root.push("new");
        root.runInputAction!(FluidInputAction.breakLine);
        root.push("line");
        root.chop;
        root.chopWord;
        root.push("few");
        root.push(" lines");
        assert(root.value == "Hello, \nnew\nfew lines");

        // Move back to last chop
        root.undo();
        assert(root.value == "Hello, \nnew\n");

        // Test redo
        root.redo();
        assert(root.value == "Hello, \nnew\nfew lines");
        root.undo();
        assert(root.value == "Hello, \nnew\n");

        // Move back through isnerts
        root.undo();
        assert(root.value == "Hello, \nnew\nline");
        root.undo();
        assert(root.value == "Hello, \nnew\n");
        root.undo();
        assert(root.value == "Hello, \nnew");
        root.undo();
        assert(root.value == "Hello, \n");
        root.undo();
        assert(root.value == "Hello, ");
        root.undo();
        assert(root.value == "");
        root.redo();
        assert(root.value == "Hello, ");
        root.redo();
        assert(root.value == "Hello, \n");
        root.redo();
        assert(root.value == "Hello, \nnew");
        root.redo();
        assert(root.value == "Hello, \nnew\n");
        root.redo();
        assert(root.value == "Hello, \nnew\nline");
        root.redo();
        assert(root.value == "Hello, \nnew\n");
        root.redo();
        assert(root.value == "Hello, \nnew\nfew lines");

        // Navigate and replace "Hello"
        root.caretIndex = 5;
        root.runInputAction!(FluidInputAction.selectPreviousWord);
        root.push("Hi");
        assert(root.value == "Hi, \nnew\nfew lines");
        assert(root.valueBeforeCaret == "Hi");

        root.undo();
        assert(root.value == "Hello, \nnew\nfew lines");
        assert(root.selectedValue == "Hello");

        root.undo();
        assert(root.value == "Hello, \nnew\n");
        assert(root.valueAfterCaret == "");

    }

    unittest {

        auto root = textInput();

        foreach (i; 0..4) {
            root.caretToStart();
            root.push("a");
        }

        assert(root.value == "aaaa");
        assert(root.valueBeforeCaret == "a");
        root.undo();
        assert(root.value == "aaa");
        assert(root.valueBeforeCaret == "");
        root.undo();
        assert(root.value == "aa");
        assert(root.valueBeforeCaret == "");
        root.undo();
        assert(root.value == "a");
        assert(root.valueBeforeCaret == "");
        root.undo();
        assert(root.value == "");

    }

    /// Produce a snapshot for the current state. Returns the snapshot.
    protected HistoryEntry snapshot() const {

        auto entry = HistoryEntry(value, selectionStart, selectionEnd, _isContinuous);

        // Get previous entry in the history
        if (!_undoStack.empty)
            entry.setPreviousEntry(_undoStack.back.value);

        return entry;

    }

    /// Restore state from snapshot
    protected HistoryEntry snapshot(HistoryEntry entry) {

        value = entry.value;
        selectSlice(entry.selectionStart, entry.selectionEnd);

        return entry;

    }

    /// Restore the last value in history.
    @(FluidInputAction.undo)
    void undo() {

        // Nothing to undo
        if (_undoStack.empty) return;

        // Push the current state to redo stack
        _redoStack.insertBack(snapshot);

        // Restore the value
        this.snapshot = _undoStack.back;
        _undoStack.removeBack;

    }

    /// Perform the last undone action again.
    @(FluidInputAction.redo)
    void redo() {

        // Nothing to redo
        if (_redoStack.empty) return;

        // Push the current state to undo stack
        _undoStack.insertBack(snapshot);

        // Restore the value
        this.snapshot = _redoStack.back;
        _redoStack.removeBack;

    }

}

unittest {

    auto root = textInput(.nullTheme, .multiline);
    auto lineHeight = root.style.getTypeface.lineHeight;

    root.value = "First one\nSecond two";
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
T wordFront(T)(T text, bool excludeWhite = false) {

    size_t length;

    T result() { return text[0..length]; }
    T remaining() { return text[length..$]; }

    while (remaining != "") {

        // Get the first character
        const lastChar = remaining.decodeFrontStatic;

        // Exclude white characters if enabled
        if (excludeWhite && lastChar.isWhite) break;

        length += lastChar.codeLength!(typeof(text[0]));

        // Stop if empty
        if (remaining == "") break;

        const nextChar = remaining.decodeFrontStatic;

        // Stop if the next character is a line feed
        if (nextChar.only.chomp.empty && !only(lastChar, nextChar).equal("\r\n")) break;

        // Continue if the next character is whitespace
        // Includes any case where the previous character is followed by whitespace
        else if (nextChar.isWhite) continue;

        // Stop if whitespace follows a non-white character
        else if (lastChar.isWhite) break;

        // Stop if the next character has different type
        else if (lastChar.isAlphaNum != nextChar.isAlphaNum) break;

    }

    return result;

}

/// ditto
T wordBack(T)(T text, bool excludeWhite = false) {

    size_t length = text.length;

    T result() { return text[length..$]; }
    T remaining() { return text[0..length]; }

    while (remaining != "") {

        // Get the first character
        const lastChar = remaining.decodeBackStatic;

        // Exclude white characters if enabled
        if (excludeWhite && lastChar.isWhite) break;

        length -= lastChar.codeLength!(typeof(text[0]));

        // Stop if empty
        if (remaining == "") break;

        const nextChar = remaining.decodeBackStatic;

        // Stop if the character is a line feed
        if (lastChar.only.chomp.empty && !only(nextChar, lastChar).equal("\r\n")) break;

        // Continue if the current character is whitespace
        // Inverse to `wordFront`
        else if (lastChar.isWhite) continue;

        // Stop if whitespace follows a non-white character
        else if (nextChar.isWhite) break;

        // Stop if the next character has different type
        else if (lastChar.isAlphaNum != nextChar.isAlphaNum) break;

    }

    return result;

}

/// `decodeFront` and `decodeBack` variants that do not mutate the range
private dchar decodeFrontStatic(T)(T range) @trusted {

    return range.decodeFront;

}

/// ditto
private dchar decodeBackStatic(T)(T range) @trusted {

    return range.decodeBack;

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

unittest {

    assert("\nabc\n".wordFront == "\n");
    assert("\n  abc\n".wordFront == "\n  ");
    assert("abc\n".wordFront == "abc");
    assert("abc  \n".wordFront == "abc  ");
    assert("  \n".wordFront == "  ");
    assert("\n     abc".wordFront == "\n     ");

    assert("\nabc\n".wordBack == "\n");
    assert("\nabc".wordBack == "abc");
    assert("abc  \n".wordBack == "\n");
    assert("abc  ".wordFront == "abc  ");
    assert("\nabc\n  ".wordBack == "\n  ");
    assert("\nabc\n  a".wordBack == "a");

    assert("\r\nabc\r\n".wordFront == "\r\n");
    assert("\r\n  abc\r\n".wordFront == "\r\n  ");
    assert("abc\r\n".wordFront == "abc");
    assert("abc  \r\n".wordFront == "abc  ");
    assert("  \r\n".wordFront == "  ");
    assert("\r\n     abc".wordFront == "\r\n     ");

    assert("\r\nabc\r\n".wordBack == "\r\n");
    assert("\r\nabc".wordBack == "abc");
    assert("abc  \r\n".wordBack == "\r\n");
    assert("abc  ".wordFront == "abc  ");
    assert("\r\nabc\r\n  ".wordBack == "\r\n  ");
    assert("\r\nabc\r\n  a".wordBack == "a");

}

@("TextInput automatically updates scrolling ancestors")
unittest {

    // Note: This theme relies on properties of the default typeface

    import fluid.scroll;

    const viewportHeight = 50;
    
    auto theme = nullTheme.derive(
        rule!Node(
            Rule.typeface = Style.defaultTypeface,
            Rule.fontSize = 20.pt,
            Rule.textColor = color("#fff"),
            Rule.backgroundColor = color("#000"),
        ),
    );
    auto input = multilineInput();
    auto root = vscrollFrame(theme, input);
    auto io = new HeadlessBackend(Vector2(200, viewportHeight));
    root.io = io;

    root.draw();
    assert(root.scroll == 0);

    // Begin typing
    input.push("FLUID\nIS\nAWESOME");
    input.caretToStart();
    input.push("FLUID\nIS\nAWESOME\n");
    root.draw();
    root.draw();

    const focusBox = input.focusBoxImpl(Rectangle(0, 0, 200, 50));

    assert(focusBox.start == input.caretPosition);
    assert(focusBox.end.y - viewportHeight == root.scroll);
    
    
}
