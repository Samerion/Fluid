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
import fluid.structs;
import fluid.popup_frame;
import fluid.text.typeface;

alias wordFront = fluid.text.wordFront;
alias wordBack  = fluid.text.wordBack;

import fluid.io.time;
import fluid.io.focus;
import fluid.io.hover;
import fluid.io.canvas;
import fluid.io.overlay;
import fluid.io.clipboard;

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
class TextInput : InputNode!Node, FluidScrollable, HoverScrollable {

    mixin InputNode!Node.enableInputActions;

    enum defaultBufferSize = 512;

    /// An interval in which the text input caret disappears and reappears. The caret will hide
    /// when half of this time passes, and will show again once the interval ends.
    enum blinkInterval = 2.seconds;

    TimeIO timeIO;
    CanvasIO canvasIO;
    ClipboardIO clipboardIO;
    OverlayIO overlayIO;

    mixin template enableInputActions() {
        import fluid.future.context : IO;
        import fluid.io.action : InputActionID, runInputActionHandler;
        override protected bool runLocalInputAction(IO io, int num, immutable InputActionID id,
            bool active)
        do {
            return runInputActionHandler(this, io, num, id, active);
        }
    }

    public {

        /// Size of the field.
        auto size = Vector2(200, 0);

        /// Time of the last interaction with the input.
        SysTime lastTouch;

        /// Time of last interaction with the input. This field uses the system clock sourced
        /// from `TimeIO`.
        ///
        /// If the new I/O is not in use, the default system `MonoTime` is used.
        MonoTime lastTouchTime;

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

            /// If true, the entry was created as a result of a small change, like inserting a character or removing
            /// a word, and can be merged with another, similar change.
            bool isMinor;

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
            bool isAdditive() const {
                return !diff.second.empty;
            }

            /// ditto
            bool isSubtractive() const {
                return !diff.first.empty;
            }

            /// Check if this entry can be merged with (newer) entry given its text content. This is used to combine
            /// runs of similar actions together, for example when typing a word, the whole word will form a single
            /// entry, instead of creating separate entries per character.
            ///
            /// Entries will only merge if they are minor, or the text didn't change. Two minor entries can be combined
            /// if they are:
            ///
            /// 1. Both additive, and the latter is not subtractive. This combines runs of inserts, including if
            ///    the first item in the run replaces some text. However, replacing text will break an existing
            ///    chain of actions.
            /// 2. Both subtractive, and neither is additive.
            ///
            /// See_Also: `isAdditive`
            bool canMergeWith(HistoryEntry nextEntry) const {

                // Always merge if nothing changed
                if (value is nextEntry.value) return true;

                if (!isMinor || !nextEntry.isMinor) return false;

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

        /// If true, movement actions select text, as opposed to clearing selection.
        bool selectionMovement;

        /// Last padding box assigned to this node, with scroll applied.
        Rectangle _inner = Rectangle(0, 0, 0, 0);

        /// Current action history, expressed as two stacks, indicating undoable and redoable actions, controllable via
        /// `undo` and `redo`. History entries are added when calling `replace` or `replaceAmend`.
        DList!HistoryEntry _undoStack;

        /// ditto
        DList!HistoryEntry _redoStack;

        /// Current history entry, if relevant.
        HistoryEntry _snapshot;

        deprecated("`_isContinuous` is deprecated in favor of `snapshot.isMinor` and will be removed in Fluid 0.9.0."
            ~ " `replaceNoHistory` or `setCaretIndexNoHistory` are also likely replacements.") {

            ref inout(bool) _isContinuous() inout {
                return _snapshot.isMinor;
            }

        }

        /// The line height used by this input, in pixels.
        ///
        /// Temporary workaround/helper function to get line height in pixels, as opposed to dots
        /// given by `Typeface`.
        float lineHeight;

    }

    private {

        /// Action used to keep the text input in view.
        ScrollIntoViewAction _scrollAction;

        /// Buffer used to store recently inserted text.
        /// See_Also: `buffer`
        char[] _buffer;

        /// Number of bytes stored in the buffer.
        size_t _usedBufferSize;

        /// Node the buffer is stored in.
        RopeNode* _bufferNode;
        invariant(_bufferNode is null || _bufferNode.left.value.sameTail(_buffer[0 .. _usedBufferSize]),
            "_bufferNode must be in sync with _buffer");

        /// Available horizontal space.
        float _availableWidth = float.nan;

        /// Visual position of the caret. See `caretRectangle`
        Rectangle _caretRectangle;

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

        this.submitted = submitted;
        this.lastTouch = Clock.currTime;
        this.contentLabel = new typeof(contentLabel);
        this.placeholder = placeholder;

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

        bool showPlaceholder;
        Text placeholderText;

        this() {
            super("");
            placeholderText = Text(this, "");
        }

        protected inout(Rope) value() inout {
            return text;
        }

        protected void replace(size_t start, size_t end, Rope value) {
            text.replace(start, end, value);
        }

        override bool hoveredImpl(Rectangle, Vector2) const {
            return false;
        }

        override void resizeImpl(Vector2 space) {

            super.resizeImpl(space);
            if (canvasIO) {
                placeholderText.resize(canvasIO, space, !isWrapDisabled);
            }
            else {
                placeholderText.resize(space, !isWrapDisabled);
            }

            if (placeholderText.size.x > minSize.x)
                minSize.x = placeholderText.size.x;

            if (placeholderText.size.y > minSize.y)
                minSize.y = placeholderText.size.y;

        }

        override void drawImpl(Rectangle outer, Rectangle inner) {

            // Don't draw background
            const style = pickStyle();

            if (showPlaceholder)
                placeholderText.draw(canvasIO, style, inner.start);
            else
                text.draw(canvasIO, style, inner.start);

        }

        override void reloadStyles() {
            // Do not load styles
        }

        override Style pickStyle() {

            // Always use default style
            return style;

        }

    }

    alias opEquals = Node.opEquals;
    override bool opEquals(const Object other) const {
        return super.opEquals(other);
    }

    /// Mark the text input as modified.
    void touch() {

        lastTouch = Clock.currTime;
        if (timeIO) {
            lastTouchTime = timeIO.now();
        }
        else {
            lastTouchTime = MonoTime.currTime;
        }
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

    /// Value written in the input. This will be displayed by the component, and will be editable by the user.
    ///
    /// To efficiently change a substring of the value, use `replace`. Reassigning via `value` is comparatively slow,
    /// as the entire text will have to be measured again.
    ///
    /// Note:
    ///     At the moment, setting `value` will not affect the undo/redo history, but this is due to change in
    ///     a future update. Use `replaceNoHistory` to keep old behavior.
    /// Params:
    ///     newValue = If given, set a new value.
    /// Returns: The value used by this input.
    inout(Rope) value() inout {

        return contentLabel.value;

    }

    /// ditto
    Rope value(Rope newValue) {

        replace(0, value.length, newValue);
        return value;

    }

    /// ditto
    Rope value(const(char)[] newValue) {

        return this.value(Rope(newValue));

    }

    /// Placeholder text that is displayed when the text input is empty.
    /// Returns: Placeholder text.
    /// Params:
    ///     value = If given, replace the current placeholder with new one.
    Rope placeholder() const {
        return contentLabel.placeholderText;
    }

    /// ditto
    Rope placeholder(Rope value) {
        return contentLabel.placeholderText = value;
    }

    /// ditto
    Rope placeholder(string value) {
        return contentLabel.placeholderText = Rope(value);
    }

    /// Replace value at a given range with a new value. This is the main, and fastest way to operate on TextInput text.
    ///
    /// There are two ways to use this function: `replace(start, end, "value")` and `replace[start..end] = value`.
    /// In a future update, it will be possible to use `value[start..end] = value` directly.
    ///
    /// This function will automatically update caretIndex: if inside the replaced area, it will be moved to the
    /// end, otherwise it will be adjusted to stay in the same spot in the text.
    ///
    /// All changes to the value will be noted in the edit history so they can be undone with `undo`. Many small,
    /// consecutive changes will be merged together they're marked as `minor`.
    ///
    /// Params:
    ///     start    = Low index, inclusive; First index to delete.
    ///     end      = High index, exclusive; First index after the newly inserted fragment.
    ///     newValue = Value to insert.
    ///     minor    = True if this is a minor change, like inserting a character or deleting a word. Similar minor
    ///         changes will be merged together in the edit history.

    /// Replace the value without making any changes to edit history.
    ///
    /// The API of this function is not yet stable.
    ///
    /// Returns: True if the value was changed, false otherwise.
    protected bool replace(size_t start, size_t end, Rope newValue, bool isMinor = false) {

        // Single line mode — filter vertical space out
        if (!multiline) {

            auto lines = newValue.byLine;

            if (lines.front.length < newValue.length) {
                newValue = lines.join(' ');
            }

        }

        // Nothing changed, ignore this request
        if (start == end && newValue.length == 0) return false;

        const oldValue = contentLabel.value[start..end];
        const oldCaretIndex = caretIndex;

        // Perform the replace
        contentLabel.replace(start, end, newValue);

        // Update caret index
        if (oldCaretIndex > start) {

            if (oldCaretIndex <= end)
                caretIndex = start + newValue.length;
            else
                caretIndex = oldCaretIndex + start + newValue.length - end;

            updateCaretPositionAndAnchor();

        }

        // Update current history entry — this doesn't affect undo/redo history, but is needed to keep integrity
        const diff = Rope.DiffRegion(start, oldValue, newValue);
        _snapshot = HistoryEntry(value, selectionStart, selectionEnd, isMinor, diff);

        // Trigger a resize
        _bufferNode = null;
        updateSize();

        return true;

    }

    /// ditto
    protected bool replace(size_t start, size_t end, string newValue, bool isMinor = false) {

        return replace(start, end, Rope(newValue), isMinor);

    }

    /// ditto
    auto replace(bool minor = false) {

        static struct Replace {

            private TextInput input;
            private bool isMinor;

            Rope opIndexAssign(Rope value, size_t[2] slice) {
                input.replace(slice[0], slice[1], value, isMinor);
                return value;
            }

            string opIndexAssign(string value, size_t[2] slice) {
                input.replace(slice[0], slice[1], Rope(value), isMinor);
                return value;
            }

            size_t[2] opSlice(size_t dim)(size_t i, size_t j) const {
                return [i, j];
            }

            size_t opDollar() const {
                return input.value.length;
            }

        }

        return Replace(this, minor);

    }

    @("TextInput.replace correctly sets cursor position (caret inside selection)")
    unittest {

        auto root = textInput();
        root.value = "foo bar baz";
        root.caretIndex = "foo ba".length;
        root.replace("foo ".length, "foo bar".length, "bazinga");

        assert(root.value == "foo bazinga baz");
        assert(root.valueBeforeCaret == "foo bazinga");

    }

    @("TextInput.replace correctly sets cursor position (caret after selection)")
    unittest {

        auto root = textInput();
        root.value = "foo bar baz";
        root.caretIndex = "foo bar ".length;
        root.replace("foo ".length, "foo bar".length, "bazinga");

        assert(root.value == "foo bazinga baz");
        assert(root.valueBeforeCaret == "foo bazinga ");

    }

    @("TextInput.replace correctly sets cursor position (caret before selection)")
    unittest {

        auto root = textInput();
        root.value = "foo bar baz";
        root.caretIndex = "foo ".length;
        root.replace("foo ".length, "foo bar".length, "bazinga");

        assert(root.value == "foo bazinga baz");
        assert(root.valueBeforeCaret == "foo ");

    }

    /// Insert text at the given position.
    void insert(size_t position, Rope value, bool minor = false) {

        replace(position, position, value, minor);

    }

    /// ditto
    void insert(size_t position, string value, bool minor = false) {

        replace(position, position, value, minor);

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
        return _scroll = value.clamp(minScroll, maxScroll);
    }

    /// Returns:
    ///     Minimum available scroll value. By default, this is always zero.
    float minScroll() const {
        return 0;
    }

    /// Returns:
    ///     Maximum available scroll value. By default, this is the width of the text, minus
    ///     the width of the input.
    float maxScroll() const {
        return max(minScroll, contentLabel.minSize.x - _availableWidth);
    }

    ///
    bool canScroll(Vector2 value) const {

        return clamp(scroll + value.x, 0, _availableWidth) != scroll;

    }

    final bool canScroll(const HoverPointer pointer) const {
        return canScroll(pointer.scroll);
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
        replace[0 .. caretIndex] = newValue;
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

        const low = selectionLowIndex;
        const high = selectionHighIndex;
        const isMinor = false;

        replace(low, high, newValue, isMinor);
        clearSelection();

        // Put the caret at the end
        caretIndex = low + newValue.length;
        updateCaretPositionAndAnchor();

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
        replace[caretIndex .. $] = newValue;
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

    /// Returns:
    ///     Visual position of the caret's center, relative to the top-left corner of the input.
    /// See_Also:
    ///     `caretRectangle`
    deprecated("caretPosition has been replaced by caretRectangle and will be removed in Fluid 0.9.0")
    Vector2 caretPosition() const {

        // Calculated in caretPositionImpl
        return _caretRectangle.center;

    }

    /// The caret is a line used to control keyboard input. Inserted text will be placed right before the caret.
    ///
    /// The caret is formed from a rectangle by connecting its top-right and bottom-left corners. This rectangle will
    /// be of zero width for regular text. For sloped text, it will be wider to reflect the slope, however this is not
    /// implemented at the moment.
    ///
    /// Returns:
    ///     A rectangle representing both ends of the caret. The caret line connects the rectangle's top-right corner
    ///     with its bottom-left corner.
    Rectangle caretRectangle() const {

        return _caretRectangle;

    }

    /// The position of the caret in the text as an index. Since the caret is placed between characters,
    /// when the caret is at the end of the text, the index is equal to the text's length.
    ///
    /// Changing the `caretIndex` will mark the last change made to the text as a major change, if it was set to minor.
    /// This means that moving the caret between two changes to the text will separate them in the undo/redo history.
    /// If this is not desired, use `setCaretIndexNoHistory`.
    ///
    /// Returns: Index of the character, byte-wise.
    /// Params:
    ///     index = If set, move the caret to a different index.
    ///         As the text is in UTF-8, this index must be on a character boundary; it cannot be in the middle
    ///         of a multibyte sequence.
    ptrdiff_t caretIndex() const {

        return _caretIndex.clamp(0, value.length);

    }

    /// ditto
    ptrdiff_t caretIndex(ptrdiff_t index) {

        _snapshot.isMinor = false;
        setCaretIndexNoHistory(index);
        return index;

    }

    /// Update the caret index without affecting the history.
    ///
    /// Multiple minor edits will be merged together in edit history unless the caret index changes in the meantime.
    /// This function will move the caret without preventing the edits from merging.
    ///
    /// Params:
    ///     index = Index to move the caret to.
    protected void setCaretIndexNoHistory(ptrdiff_t index) {

        if (!isSelecting) {
            _selectionStart = index;
        }

        touch();
        _bufferNode = null;
        _caretIndex = index;

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

        use(timeIO);
        use(canvasIO);
        use(focusIO);
        use(hoverIO);
        use(overlayIO);
        use(clipboardIO);

        // Initialize touch time
        if (timeIO && lastTouchTime == MonoTime.init) {
            lastTouchTime = timeIO.now();
        }

        super.resizeImpl(area);

        // Set the size
        minSize = size;

        const isFill = layout.nodeAlign[0] == NodeAlign.fill;

        _availableWidth = isFill
            ? area.x
            : size.x;

        const textArea = multiline
            ? Vector2(_availableWidth, area.y)
            : Vector2(0, size.y);

        // Resize the label, and remove the spacing
        contentLabel.showPlaceholder = value == "";
        contentLabel.style = pickLabelStyle(style);
        resizeChild(contentLabel, textArea);

        const scale = canvasIO.toDots(Vector2(0, 1)).y;
        lineHeight = style.getTypeface.lineHeight / scale;

        const minLines = multiline ? 3 : 1;

        // Set height to at least the font size, or total text size
        minSize.y = max(minSize.y, lineHeight * minLines, contentLabel.minSize.y);

        // Locate the cursor
        updateCaretPositionAndAnchor();

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
            _caretRectangle.x = float.nan;
            return;
        }

        _caretRectangle = caretRectangleImpl(_availableWidth, preferNextLine);

        const scrolledCaret = _caretRectangle.x - scroll;

        // Scroll to make sure the caret is always in view
        const scrollOffset
            = scrolledCaret > _availableWidth ? scrolledCaret - _availableWidth
            : scrolledCaret < 0               ? scrolledCaret
            : 0;

        // Set the scroll
        scroll = multiline
            ? 0
            : scroll + scrollOffset;

    }

    alias indexAt = nearestCharacter;

    /// ditto
    void updateCaretPositionAndAnchor(bool preferNextLine = false) {

        updateCaretPosition(preferNextLine);
        horizontalAnchor = caretRectangle.x;

    }

    /// Find the closest index to the given position.
    /// Returns: Index of the character. The index may be equal to text length.
    size_t nearestCharacter(Vector2 needle) {

        return contentLabel.text.indexAt(canvasIO, needle);

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
    ///     minimumSize = Minimum size to allocate for the buffer. More may be allocated to allow for future input.
    protected void newBuffer(size_t minimumSize = defaultBufferSize) {

        const newSize = max(minimumSize, defaultBufferSize);

        _buffer = new char[newSize];
        usedBufferSize = 0;

    }

    protected Rectangle caretRectangleImpl(float, bool preferNextLine) {
        const ruler = rulerAt(caretIndex, preferNextLine);
        return Rectangle(
            canvasIO.fromDots(ruler.caret.start).tupleof,
            canvasIO.fromDots(ruler.caret.size).tupleof);
    }

    /// Returns: A text ruler measuring text between the start and a chosen character.
    /// See_Also: `Text.rulerAt`
    /// Params:
    ///     index = Index of the requested character.
    TextRuler rulerAt(size_t index, bool preferNextLine = false) {

        return contentLabel.text.rulerAt(index, preferNextLine);

    }

    CachedTextRuler rulerAtPosition(Vector2 position) {
        return contentLabel.text.rulerAtPosition(canvasIO, position);
    }

    /// Returns: `TextInterval` measuing all characters between the start of text, and the given index.
    /// Params:
    ///     index = Index of character to find the interval for.
    TextInterval intervalAt(size_t index) {

        return contentLabel.text.intervalAt(index);

    }

    protected override void drawImpl(Rectangle outer, Rectangle inner) @trusted {

        auto style = pickStyle();

        // Fill the background
        style.drawBackground(canvasIO, outer);

        // Copy style to the label
        contentLabel.style = pickLabelStyle(style);

        // Scroll the inner rectangle
        auto scrolledInner = inner;
        scrolledInner.x -= scroll;

        // Save the inner box
        _inner = scrolledInner;

        // Increase the size of the inner box so that tree doesn't turn on scissors mode on its own
        scrolledInner.w += scroll;

        const lastArea = canvasIO.intersectCrop(outer);
        scope (exit) canvasIO.cropArea = lastArea;

        // Draw the contents
        drawContents(inner, scrolledInner);
    }

    protected void drawContents(Rectangle, Rectangle scrolledInner) {

        // Draw selection
        drawSelection(scrolledInner);

        // Draw the text
        drawChild(contentLabel, scrolledInner);

        // Draw the caret
        drawCaret(scrolledInner);

    }

    protected void drawCaret(Rectangle inner) {

        // Add a blinking caret
        if (isCaretVisible) {

            const caretRect = this.caretRectangle();
            const bottomLeft = start(inner)
                + Vector2(caretRect.x, caretRect.y + caretRect.height);
            const topRight = start(inner)
                + Vector2(caretRect.x + caretRect.width, caretRect.y);

            // Draw the caret
            canvasIO.drawLine(topRight, bottomLeft, 1, style.textColor);

        }

    }

    override Rectangle focusBoxImpl(Rectangle inner) const {

        const position = inner.start + caretRectangle.start;
        const size     = caretRectangle.size;

        return Rectangle(
            position.tupleof,
            size.x + 1, size.y,
        );

    }

    /// Get an appropriate text ruler for this input.
    protected TextRuler textRuler() {

        return TextRuler(style.getTypeface, multiline ? _availableWidth : float.nan);

    }

    /// Draw selection, if applicable.
    protected void drawSelection(Rectangle inner) {
        import optional : some;

        // Ignore if selection is empty
        if (selectionStart == selectionEnd) return;

        const cropArea = canvasIO.cropArea;
        auto low = selectionLowIndex;
        const high = selectionHighIndex;

        Vector2 scale(Vector2 input) {
            return canvasIO.fromDots(input);
        }

        auto style = pickStyle();
        auto typeface = style.getTypeface;
        auto ruler = rulerAt(low);

        // Some text is overflowing
        if (inner.y < 0) {

            auto topRuler = rulerAtPosition(Vector2(0, -inner.y));

            if (topRuler.point.length > low) {
                ruler = topRuler;
                low = topRuler.point.length;
            }

        }

        Vector2 lineStart = Vector2(float.nan, float.nan);
        Vector2 lineEnd;

        // Run through the text
        foreach (line; value[low..$].byLine) {

            auto index = low + line.index;

            scope (exit) ruler.startLine();

            // Each word is a single, unbreakable unit
            foreach (word, penPosition; typeface.eachWord(ruler, line, multiline)) {

                const caret = ruler.caret(penPosition);
                const startIndex = index;
                const endIndex = index = startIndex + word.length;

                scope (exit) lineEnd = scale(ruler.caret.end);

                // Started a new line, draw the last line
                if (scale(caret.start).y != lineStart.y) {

                    // Don't draw if selection starts here
                    if (startIndex != low) {
                        const rect = Rectangle(
                            (inner.start + lineStart).tupleof,
                            (lineEnd - lineStart).tupleof
                        );

                        canvasIO.drawRectangle(rect, style.selectionBackgroundColor);
                    }

                    // Restart the line
                    auto startRuler = ruler;
                    startRuler.penPosition = penPosition;
                    lineStart = scale(startRuler.caret.start);

                }

                // Selection ends here
                if (startIndex <= high && high <= endIndex) {

                    const dent = typeface.measure(word[0 .. high - startIndex]);
                    const lineEnd = scale(caret.end + Vector2(dent.x, 0));
                    const rect = Rectangle(
                        (inner.start + lineStart).tupleof,
                        (lineEnd - lineStart).tupleof
                    );

                    canvasIO.drawRectangle(rect, style.selectionBackgroundColor);
                    return;

                }

                // Stop drawing when selection is offscreen
                const isOffscreen = !cropArea.empty
                    && inner.start.y + ruler.caret.y > cropArea.front.end.y;
                if (isOffscreen) return;

            }

        }

    }

    /// Returns:
    ///     True if the caret should be visible, or false if not.
    bool isCaretVisible() {

        // Ignore the rest if the node isn't focused
        if (!isFocused || blocksInput) return false;

        const now = timeIO
            ? timeIO.now
            : MonoTime.currTime;
        auto blinkProgress = (now - lastTouchTime) % blinkInterval;

        // Add a blinking caret if there is no selection
        return selectionStart == selectionEnd && blinkProgress < blinkInterval/2;

    }

    deprecated("showCaret has been renamed to isCaretVisible, "
        ~ "and will be removed in Fluid 0.8.0")
    protected bool showCaret() {
        return isCaretVisible();
    }

    protected override bool focusImpl() {

        import std.uni : isAlpha, isWhite;
        import std.range : back;

        bool changed;

        // Read text off FocusIO
        if (focusIO) {
            int offset;
            char[1024] buffer;

            // Read text
            while (true) {

                // Push the text
                if (auto text = focusIO.readText(buffer, offset)) {
                    push(text);
                }
                else break;

            }

            // Mark as changed
            if (offset != 0) {
                changed = true;
            }
        }

        // Typed something
        if (changed) {
            touchText();
            return true;
        }

        return true;

    }

    @("TextInput.push reuses the text buffer; creates undo entries regardless of buffer")
    unittest {

        auto root = textInput();
        root.value = "Ho";

        root.caretIndex = 1;
        root.savePush("e");
        assert(root.value.byNode.equal(["H", "e", "o"]));
        assert(root.caretIndex == 2);

        root.savePush("n");

        assert(root.value.byNode.equal(["H", "en", "o"]));
        assert(root.caretIndex == 3);

        root.savePush("l");
        assert(root.value.byNode.equal(["H", "enl", "o"]));
        assert(root.caretIndex == 4);

        // Create enough text to fill the buffer
        // A new node should be created as a result
        auto bufferFiller = 'A'.repeat(root.freeBuffer.length).array;

        root.savePush(bufferFiller);
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

    version (TODO)
    unittest {

        auto io = new HeadlessBackend;
        auto root = textInput("placeholder");

        root.io = io;

        // Empty text
        {
            root.draw();

            assert(root.value == "");
            assert(root.contentLabel.text == "");
            assert(root.contentLabel.placeholderText == "placeholder");
            assert(root.contentLabel.showPlaceholder);
            assert(root.isEmpty);
        }

        // Focus the box and input stuff
        {
            io.nextFrame;
            io.inputCharacter("¡Hola, mundo!");
            root.focus();
            root.draw();

            assert(root.value == "¡Hola, mundo!");

            io.nextFrame;
            root.draw();

            assert(!root.contentLabel.showPlaceholder);
        }

        // The text will be displayed the next frame
        {
            io.nextFrame;
            root.draw();

            assert(root.contentLabel.text == "¡Hola, mundo!");
            assert(root.isFocused);
        }

    }

    /// Hook into input actions to create matching history entries.
    ///
    /// See_Also: [savePush], [snapshot], [pushHistory]
    override bool actionImpl(IO io, int number, immutable InputActionID id, bool isActive) {

        // Passive events should not create snapshots
        const doSnapshot = isActive
            && id != inputActionID!(FluidInputAction.undo)
            && id != inputActionID!(FluidInputAction.redo);

        const past = snapshot();
        _snapshot.diff = Rope.DiffRegion.init;

        // Run the input action and compare changes to send to history
        const handled = runLocalInputAction(io, number, id, isActive);
        if (handled && doSnapshot) {
            pushHistory(past);
        }

        return handled;

    }

    /// Operating on `TextInput` contents using exposed methods will not create any history
    /// entries:
    @("TextInput methods do not create history entries")
    unittest {

        auto root = multilineInput();
        root.value = "Hello, !";
        root.replace(7, 7, "World");
        root.replace(7, 7+5, "Fluid");
        root.caretToEnd();
        root.breakLine();
        root.undo();  // does nothing
        assert(root.value == "Hello, Fluid!\n");

    }

    /// This behavior is different for changes made through input actions, as they directly
    /// correspond to changes made by the user.
    @("TextInput.runInputAction will create history entries")
    unittest {
        auto root = multilineInput();
        root.savePush("Hello, World!");
        root.runInputAction!(FluidInputAction.previousChar);
        root.runInputAction!(FluidInputAction.backspaceWord);
        root.savePush("Fluid");
        assert(root.value == "Hello, Fluid!");
        root.undo();
        assert(root.value == "Hello, !");
        root.undo();
        assert(root.value == "Hello, World!");
    }

    protected bool runLocalInputAction(IO io, int num, immutable InputActionID id, bool active) {
        return runInputActionHandler(this, io, num, id, active);
    }

    /// Write text at the caret position and save the result to history.
    ///
    /// The `savePush` family of functions wraps `push`.
    ///
    /// See_Also:
    ///     `push`
    /// Params:
    ///     character = The character to insert.
    ///     text      = Text to insert.
    ///     isMinor   = If true, this is a minor change. Consecutive minor changes will be merged together.
    final void savePush(dchar character, bool isMinor = true) {

        const past = snapshot();
        push(character, isMinor);
        pushHistory(past);

    }

    /// ditto
    final void savePush(scope const(char)[] text, bool isMinor = true) {

        const past = snapshot();
        push(text, isMinor);
        pushHistory(past);

    }

    /// ditto
    final void savePush(Rope text, bool isMinor = true) {

        const past = snapshot();
        push(text, isMinor);
        pushHistory(past);

    }

    /// Push a character or string to the input.
    final void push(dchar character, bool isMinor = true) {

        char[4] buffer;

        auto size = buffer.encode(character);
        push(buffer[0..size], isMinor);

    }

    /// ditto
    void push(scope const(char)[] ch, bool isMinor = true) {

        // TODO `push` should *not* have isMinor = true as default for API consistency
        //      it does for backwards compatibility

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

        // Save the data in the buffer, unless they're the same
        if (slice[] !is ch[]) {
            slice[] = ch[];
        }
        _usedBufferSize += ch.length;

        // Selection is active, overwrite it
        // This should be done even if given text is empty, effectively removing the selection
        if (isSelecting) {

            bufferNode = new RopeNode(Rope(slice), Rope.init);
            push(Rope(bufferNode));
            return;

        }

        // Nothing to insert, so nothing will change
        if (ch == "") return;

        // The above `if` handles the one case where `push` doesn't just add new characters to the text.
        // From here, appending can be optimized by memorizing the node we create to add the text, and reusing it
        // afterwards. This way, we avoid creating many one character nodes.

        const oldCaretIndex = caretIndex;
        const newCaretIndex = caretIndex + ch.length;

        // Create a node to write to
        if (!bufferNode) {

            bufferNode = new RopeNode(Rope(slice), Rope.init);

            // Insert the node
            insert(caretIndex, Rope(bufferNode), isMinor);

        }

        // If writing in a single sequence, reuse the last inserted node
        else {

            const originalLength = bufferNode.length;

            // Append the character to its value
            // The bufferNode will always share tail with the buffer
            bufferNode.left = usedBuffer[$ - originalLength - ch.length .. $];

            // Update the node
            replace(caretIndex - originalLength, caretIndex, Rope(bufferNode), isMinor);

            // Change the history for this change so only the new characters are seen
            snapshot.diff.start = oldCaretIndex;
            snapshot.diff.first = Rope.init;
            snapshot.diff.second = Rope(bufferNode)[$ - ch.length .. $];

            assert(!snapshot.isSubtractive);
            assert( snapshot.isAdditive);

        }

        // Insert the text by replacing the old node, if present
        assert(value.isBalanced);

        setCaretIndexNoHistory(newCaretIndex);
        updateCaretPositionAndAnchor();

    }

    /// ditto
    void push(Rope text, bool isMinor = true) {

        const newCaretIndex = caretIndex + text.length;

        // If selection is active, overwrite the selection
        if (isSelecting) {
            replace(selectionLowIndex, selectionHighIndex, text, isMinor);
            clearSelection();
        }

        // Insert the character before caret
        else {
            insert(caretIndex, text, isMinor);
        }

        // Put the caret at the end
        setCaretIndexNoHistory(newCaretIndex);
        updateCaretPositionAndAnchor();

    }

    /// Start a new line
    @(FluidInputAction.breakLine)
    bool breakLine() {

        if (!multiline) return false;

        const isMinor = false;

        push('\n', isMinor);

        return true;

    }

    unittest {

        auto root = textInput();

        root.push("hello");
        root.runInputAction!(FluidInputAction.breakLine);

        assert(root.value == "hello");

    }

    /// Submit the input.
    @(FluidInputAction.submit)
    void submit() {

        import std.sumtype : match;

        // Run the callback
        if (submitted) submitted();

    }

    /// Erase last word before the caret, or the first word after.
    ///
    /// Params:
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
            replace[caretIndex .. caretIndex + erasedWord.length] = Rope.init;

        }

        // Remove previous word
        else {

            // Find the word to delete
            const erasedWord = valueBeforeCaret.wordBack;

            // Remove the word
            replace[caretIndex - erasedWord.length .. caretIndex] = Rope.init;

        }

    }

    /// Remove a word before the caret.
    @(FluidInputAction.backspaceWord)
    void backspaceWord() {

        chopWord();
        touchText();

    }

    /// Delete a word in front of the caret.
    @(FluidInputAction.deleteWord)
    void deleteWord() {

        chopWord(true);
        touchText();

    }

    /// Erase any character preceding the caret, or the next one.
    /// Params:
    ///     forward = If true, removes character after the caret, otherwise removes the one before.
    void chop(bool forward = false) {

        const isMinor = true;

        // Selection active
        if (isSelecting) {

            selectedValue = null;

        }

        // Remove next character
        else if (forward) {

            if (valueAfterCaret == "") return;

            const length = valueAfterCaret.decodeFrontStatic.codeLength!char;

            replace(isMinor)[caretIndex .. caretIndex + length] = Rope.init;

        }

        // Remove previous character
        else {

            if (valueBeforeCaret == "") return;

            const length = valueBeforeCaret.decodeBackStatic.codeLength!char;

            replace(isMinor)[caretIndex - length .. caretIndex] = Rope.init;

        }

        // Trigger the callback
        touchText();

    }

    private {

        /// Number of clicks performed within short enough time from each other. First click is number 0.
        int _clickCount;

        /// Time of the last `press` event, used to enable double click and triple click selection.
        SysTime _lastClick;

        /// Position of the last click.
        Vector2 _lastClickPosition;

    }

    /// Switch hover selection mode.
    ///
    /// A single click+hold will use per-character selection. A double click+hold will select whole words,
    /// and a triple click+hold will select entire lines.
    @(FluidInputAction.press)
    protected void press(HoverPointer pointer) {

        enum maxDistance = 5;

        version (none) {
            // To count as repeated, the click must be within the specified double click time, and close enough
            // to the original location
            const isRepeated = Clock.currTime - _lastClick < io.doubleClickTime  /* TODO GET RID */
                && distance(pointer.position, _lastClickPosition) < maxDistance;

            // Count repeated clicks
            _clickCount = isRepeated
                ? _clickCount + 1
                : 0;

            // Register the click
            _lastClick = Clock.currTime;
            _lastClickPosition = pointer.position;
        }

    }

    /// Update selection using the mouse.
    @(FluidInputAction.press, WhileHeld)
    protected void pressAndHold(HoverPointer pointer) {

        // Move the caret with the mouse
        caretToPointer(pointer);
        moveOrClearSelection();

        // Turn on selection from now on, disable it once released
        selectionMovement = true;

        // Multi-click not supported
        if (pointer.clickCount == 0) return;

        final switch ((pointer.clickCount + 2) % 3) {

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

    }

    protected override bool hoverImpl(HoverPointer) {

        // Disable selection when not holding
        if (hoverIO) {
            selectionMovement = false;
        }
        return false;

    }

    protected override void scrollImpl(Vector2 value) {

        const speed = ScrollInput.scrollSpeed;
        const move = speed * value.x;

        scroll = scroll + move;

    }

    protected override bool scrollImpl(HoverPointer pointer) {
        scroll = scroll + pointer.scroll.x;
        return true;
    }

    Rectangle shallowScrollTo(const Node, Rectangle, Rectangle childBox) {

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
        import fluid.text.typeface;

        const backLength = value[0..index].byLineReverse.front.length;
        const frontLength = value[index..$].byLine.front.length;
        const start = index - backLength;
        const end = index + frontLength;
        size_t[2] selection = [selectionStart, selectionEnd];

        // Combine everything on the same line, before and after the caret
        replace(start, end, newValue);

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

    /// Change the current line. Moves the cursor to the end of the newly created line.
    const(char)[] caretLine(const(char)[] newValue) {

        return lineByIndex(caretIndex, newValue);

    }

    /// ditto
    Rope caretLine(Rope newValue) {

        return lineByIndex(caretIndex, newValue);

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

    /// Iterate on each line in an interval.
    ///
    /// Warning: Iterating on the line by reference is now deprecated.
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
                    if (front.chomp !is originalFront) {
                        setLine(originalFront, front);
                    }
                    else {
                        const newNextLine = input.value.nextLineByIndex(lineStart);
                        end += newNextLine - nextLine;
                        nextLine = newNextLine;
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

    /// Return each line containing the selection.
    auto eachSelectedLine() {

        return eachLineByIndex(selectionLowIndex, selectionHighIndex);

    }

    /// Open the input's context menu.
    @(FluidInputAction.contextMenu)
    void openContextMenu(HoverPointer pointer) {

        // Move the caret to the pointer's position
        if (!isSelecting)
            caretToPointer(pointer);

    }

    /// Open the input's context menu.
    @(FluidInputAction.contextMenu)
    void openContextMenu() {

        const anchor = focusBoxImpl(_inner);

        // Spawn the popup at caret position
        overlayIO.addPopup(contextMenu, anchor);

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

    /// Clear the value of this input field, making it empty.
    void clear()
    out(; isEmpty)
    do {

        // Remove the value
        value = null;

        clearSelection();
        updateCaretPositionAndAnchor();

    }

    version (TODO)
    unittest {

        auto io = new HeadlessBackend;
        auto root = textInput();

        io.inputCharacter("Hello, World!");
        root.io = io;
        root.focus();
        root.draw();

        auto value1 = root.value;

        root.chop();

        assert(value1     == "Hello, World!");
        assert(root.value == "Hello, World");

        auto value2 = root.value;
        root.chopWord();

        assert(value2     == "Hello, World");
        assert(root.value == "Hello, ");

        auto value3 = root.value;
        root.clear();

        assert(value3     == "Hello, ");
        assert(root.value == "");

    }

    version (TODO)
    unittest {

        auto io = new HeadlessBackend;
        auto root = textInput();

        io.inputCharacter("Hello, World");
        root.io = io;
        root.focus();
        root.draw();

        auto value1 = root.value;

        root.chopWord();

        assert(value1     == "Hello, World");
        assert(root.value == "Hello, ");

        auto value2 = root.value;

        root.push("Moon");

        assert(value2     == "Hello, ");
        assert(root.value == "Hello, Moon");

        auto value3 = root.value;

        root.clear();

        assert(value3     == "Hello, Moon");
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

    /// Select the whole line the cursor is.
    void selectLine() {

        const isLow = selectionStart <= selectionEnd;

        foreach (line; value.byLine) {

            const lineStart = line.index;
            const lineEnd = lineStart + line.length;

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

        updateCaretPositionAndAnchor(false);

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

        updateCaretPositionAndAnchor(true);

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

        updateCaretPositionAndAnchor(true);
        moveOrClearSelection();

    }

    /// Move the caret to the previous or next line.
    @(FluidInputAction.previousLine, FluidInputAction.nextLine)
    protected void previousOrNextLine(FluidInputAction action) {

        auto typeface = style.getTypeface;
        auto search = Vector2(horizontalAnchor, caretRectangle.center.y);

        // Next line
        if (action == FluidInputAction.nextLine) {
            search.y += lineHeight;
        }

        // Previous line
        else {
            search.y -= lineHeight;
        }

        caretTo(search);
        updateCaretPosition(horizontalAnchor < 1);
        moveOrClearSelection();

    }

    /// Move the caret to the given screen position (viewport space).
    /// Params:
    ///     position = Position in the screen to move the cursor to.
    void caretTo(Vector2 position) {

        caretIndex = nearestCharacter(position);

    }

    /// ditto
    void caretToPointer(HoverPointer pointer) {

        caretTo(pointer.position - _inner.start);
        updateCaretPositionAndAnchor(false);

    }

    /// Move the caret to the beginning of the line. This function perceives the line visually, so if the text wraps, it
    /// will go to the beginning of the visible line, instead of the hard line break.
    @(FluidInputAction.toLineStart)
    void caretToLineStart() {

        const search = Vector2(0, caretRectangle.center.y);

        caretTo(search);
        updateCaretPositionAndAnchor(true);
        moveOrClearSelection();

    }

    /// Move the caret to the end of the line.
    @(FluidInputAction.toLineEnd)
    void caretToLineEnd() {

        const search = Vector2(float.infinity, caretRectangle.center.y);

        caretTo(search);
        updateCaretPositionAndAnchor(false);
        moveOrClearSelection();

    }

    /// Move the caret to the beginning of the input
    @(FluidInputAction.toStart)
    void caretToStart() {

        caretIndex = 0;
        updateCaretPositionAndAnchor(true);
        moveOrClearSelection();

    }

    /// Move the caret to the end of the input
    @(FluidInputAction.toEnd)
    void caretToEnd() {

        caretIndex = value.length;
        updateCaretPositionAndAnchor(false);
        moveOrClearSelection();

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

        assert(value1     == "foo bar baz");
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

        copy();
        selectedValue = null;

    }

    /// Copy selected text to clipboard.
    @(FluidInputAction.copy)
    void copy() {
        if (!isSelecting) return;
        clipboardIO.writeClipboard = selectedValue.toString();
    }

    /// Paste text from clipboard.
    @(FluidInputAction.paste)
    void paste() {
        const isMinor = false;
        auto snap = snapshot();

        char[1024] buffer;
        int offset;
        Rope result;

        // Read text
        while (true) {
            if (auto text = clipboardIO.readClipboard(buffer, offset)) {
                result ~= text.dup;
            }
            else break;
        }

        push(result, isMinor);
    }

    /// Clear the undo/redo action history.
    ///
    /// Calling this will erase both the undo and redo stack, making it impossible to restore any changes made in prior,
    /// through means such as Ctrl+Z and Ctrl+Y.
    void clearHistory() {

        _undoStack.clear();
        _redoStack.clear();

    }

    deprecated("`pushSnapshot` and `forcePushSnapshot` have been replaced by `pushHistory`/`forcePushHistory`"
        ~ " and will be removed in Fluid 0.9.0.") {

        void pushSnapshot(HistoryEntry entry) {
            pushHistory(entry);
        }
        void forcePushSnapshot(HistoryEntry entry) {
            forcePushHistory(entry);
        }

    }

    /// Push the given state snapshot (value, caret & selection) into the undo stack. Refuses to push if the current
    /// state can be merged with it, unless `forcePushSnapshot` is used.
    ///
    /// A snapshot pushed through `forcePushHistory` will break continuity — it will not be merged with any other
    /// snapshot.
    ///
    /// History:
    ///     As of Fluid 0.7.1, this function now replaces the old `pushSnapshot`. `psuhHistory` does not have
    ///     to be called explicitly. `replace` will automatically call this whenever needed. It can still be
    ///     useful when used together with `replaceNoHistory`
    /// Params:
    ///     newSnapshot = Entry to insert into the `undo` history. This entry should be a revision *preceding*
    ///         the current state.
    /// Returns:
    ///     True if the snapshot was added to history, or false if not.
    bool pushHistory(HistoryEntry newSnapshot) {

        if (!newSnapshot.canMergeWith(snapshot)) {
            forcePushHistory(newSnapshot);
            return true;
        }

        else return false;

    }

    /// ditto
    void forcePushHistory(HistoryEntry newSnapshot) {

        _undoStack.insertBack(newSnapshot);

    }

    /// Replacing text and saving the change to history.
    unittest {

        auto root = textInput();

        // Take a snapshot of the node's status before the change
        auto past = root.snapshot;

        if (root.replace(0, 0, "Hello, World!")) {

            // Once the change is performed, push the snapshot to history
            root.pushHistory(past);

        }

        // Now, the change can easily be undone
        assert(root.value == "Hello, World!");
        root.undo();
        assert(root.value == "");

    }

    /// Returns: History entry for the current state.
    protected const(HistoryEntry) snapshot() const {

        HistoryEntry snap = _snapshot;
        snap.selectionStart = selectionStart;
        snap.selectionEnd   = selectionEnd;
        return snap;

    }

    /// ditto
    protected ref HistoryEntry snapshot() {

        const that = this;
        _snapshot = that.snapshot;
        return _snapshot;

    }

    /// Restore state from snapshot.
    deprecated("`snapshot(HistoryEntry)` is deprecated and will be removed in Fluid 0.9.0."
        ~ " Please use `restoreSnapshot` instead.")
    protected HistoryEntry snapshot(HistoryEntry entry) {

        restoreSnapshot(entry);
        return entry;

    }

    /// Restore state from snapshot.
    protected void restoreSnapshot(HistoryEntry entry) {

        // TODO this could be faster
        replace(0, value.length, entry.value);
        selectSlice(entry.selectionStart, entry.selectionEnd);
        _snapshot = entry;

    }

    /// Restore the last value in history.
    @(FluidInputAction.undo)
    void undo() {

        // Nothing to undo
        if (_undoStack.empty) return;

        // Push the current state to redo stack
        _redoStack.insertBack(snapshot);

        // Restore the value
        restoreSnapshot(_undoStack.back);
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
        restoreSnapshot(_redoStack.back);
        _redoStack.removeBack;

    }

}

version (TODO)
@("TextInput paste benchmark")
unittest {

    import std.file;
    import std.datetime.stopwatch;

    auto input = multilineInput(
        .layout!"fill",
    );
    auto root = vscrollFrame(
        .layout!"fill",
        input
    );
    auto io = new HeadlessBackend;

    // Prepare
    root.io = io;
    io.clipboard = readText(__FILE__);
    root.draw();
    input.focus();
    io.nextFrame();

    const runCount = 10;

    // Paste the text
    auto result = benchmark!({
        input.value = "";
        input.paste();
        root.draw();
    })(runCount);

    const average = result[0] / runCount;

    // This should be trivial on practically any machine
    assert(average <= 100.msecs, "Too slow: average " ~ average.toString);
    if (average > 10.msecs) {
        import std.stdio;
        writeln("Warning: TextInput paste benchmark runs slowly, ", average);
    }

}

@("TextInput edit after paste benchmark")
version (TODO)
unittest {

    import std.file;
    import std.datetime.stopwatch;

    auto input = multilineInput(
        .layout!"fill",
    );
    auto root = vscrollFrame(
        .layout!"fill",
        input
    );
    auto io = new HeadlessBackend;
    io.clipboard = readText(__FILE__);

    root.io = io;
    root.draw();
    input.focus();
    input.paste();
    io.nextFrame();
    root.draw();

    const runCount = 10;

    // Paste the text
    auto result = benchmark!(

        // At the start
        {
            input.insert(0, "Hello, World!");
            root.draw();
        },

        // Into the middle
        {
            input.insert(input.value.length / 2, "Hello, World!");
            root.draw();
        },

        // At the end
        {
            input.insert(input.value.length, "Hello, World!");
            root.draw();
        },

    )(runCount);

    auto average = result[].map!(a => a / runCount);
    const totalAverage = average.sum / result[].length;

    assert(totalAverage <= 20.msecs, format!"Too slow: average %(%s / %)"(average));
    if (totalAverage > 5.msecs) {
        import std.stdio;
        writefln!"Warning: TextInput edit after paste benchmark runs slowly, %(%s / %)"(average);
    }

}

version (TODO)
@("TextInput loads of small edits benchmark")
unittest {

    import std.file;
    import std.datetime.stopwatch;

    auto root = multilineInput();
    auto io = new HeadlessBackend;
    io.clipboard = readText(__FILE__);

    root.io = io;
    root.draw();
    root.focus();
    root.paste();
    io.nextFrame();
    root.draw();
    root.caretIndex = 0;

    const runCount = 1;  // TODO make this greater once you fix this performance please
    const sampleText = "Hello, world! This is some text I'd like to type in. This should be fast.";

    // Type in the text
    auto result = benchmark!({

        foreach (letter; sampleText) {
            root.push(letter);
            root.draw();
        }

    })(runCount);

    const average = result[0] / runCount;
    const averageCharacter = average / sampleText.length;

    assert(averageCharacter <= 20.msecs, format!"Too slow: average %s per character"(averageCharacter));
    if (averageCharacter > 5.msecs) {
        import std.stdio;
        writefln!"Warning: TextInput loads of small edits benchmark runs slowly, %s per character"(averageCharacter);
    }

}
