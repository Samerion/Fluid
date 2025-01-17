module fluid.code_input;

import std.range;
import std.string;
import std.algorithm;

import fluid.text;
import fluid.input;
import fluid.utils;
import fluid.style;
import fluid.backend;
import fluid.text_input;


@safe:


/// Node parameter for `CodeInput` enabling tabs as the character used for indents.
/// Params:
///     width = Indent width; number of character a single tab corresponds to. Optional, if set to 0 or left default,
///         keeps the old/default value.
auto useTabs(int width = 0) {

    struct UseTabs {

        int width;

        void apply(CodeInput node) {
            node.useTabs = true;
            if (width)
                node.indentWidth = width;
        }

    }

    return UseTabs(width);

}

/// Node parameter for `CodeInput`, setting spaces as the character used for indents.
/// Params:
///     width = Indent width; number of spaces a single indent consists of.
auto useSpaces(int width) {

    struct UseSpaces {

        int width;

        void apply(CodeInput node) {
            node.useTabs = false;
            node.indentWidth = width;
        }

    }

    return UseSpaces(width);

}


/// A CodeInput is a special variant of `TextInput` that provides syntax highlighting and a gutter (column with line
/// numbers).
alias codeInput = simpleConstructor!CodeInput;

/// ditto
class CodeInput : TextInput {

    mixin enableInputActions;

    enum maxIndentWidth = 16;

    public {

        CodeHighlighter highlighter;
        CodeIndentor indentor;

        /// Additional context to pass to the highlighter. Will not be displayed, but can be used to improve syntax
        /// highlighting and code analysis.
        Rope prefix;

        /// ditto
        Rope suffix;

        /// Character width of a single indent level.
        int indentWidth = 4;
        invariant(indentWidth <= maxIndentWidth);

        /// If true, uses the tab character for indents.
        bool useTabs = false;

    }

    public {

        /// Current token type, used for styling individual token types and **only relevant in themes**.
        const(char)[] token;

    }

    private {

        struct AutomaticFormat {

            bool pending;
            int oldTargetIndent;

            this(int oldTargetIndent) {
                this.pending = true;
                this.oldTargetIndent = oldTargetIndent;
            }

        }

        /// If automatic reformatting is to take place, `pending` is set to true, with `oldTargetIndent` set to the
        /// previous value of the indent. This value is compared against the current target, and the reformatter will
        /// only activate if there was a change.
        AutomaticFormat _automaticFormat;

    }

    this(CodeHighlighter highlighter = null, void delegate() @safe submitted = null) {

        this.submitted = submitted;
        this.highlighter = highlighter;
        this.indentor = cast(CodeIndentor) highlighter;
        super.contentLabel = new ContentLabel;

    }

    inout(ContentLabel) contentLabel() inout {

        return cast(inout ContentLabel) super.contentLabel;

    }

    override bool multiline() const {

        return true;

    }

    class ContentLabel : TextInput.ContentLabel {

        /// Use our own `Text`.
        StyledText!CodeHighlighterRange text;
        Style[256] styles;

        this() {
            text = typeof(text)(this, "", CodeHighlighterRange.init);
            text.hasFastEdits = true;
        }

        override void resizeImpl(Vector2 available) {

            assert(text.hasFastEdits);

            use(canvasIO);

            auto typeface = style.getTypeface;
            typeface.setSize(io.dpi, style.fontSize);

            this.text.value = super.text.value;
            text.indentWidth = indentWidth * typeface.advance(' ').x / io.hidpiScale.x;
            text.resize(available);
            minSize = text.size;

        }

        override void drawImpl(Rectangle outer, Rectangle inner) {

            const style = pickStyle();
            text.draw(canvasIO, styles, inner.start);

        }

    }

    /// Get the full value of the text, including context provided via `prefix` and `suffix`.
    Rope sourceValue() const {

        // TODO This will allocate. Can it be avoided?
        return prefix ~ value ~ suffix;

    }

    /// Get a rope representing given indent level.
    Rope indentRope(int indentLevel = 1) const {

        static tabRope = const Rope("\t");
        static spaceRope = const Rope("                ");

        static assert(spaceRope.length == maxIndentWidth);

        Rope result;

        // TODO this could be more performant by using as much of a single rope as possible

        // Insert a tab
        if (useTabs)
            foreach (i; 0 .. indentLevel) {

                result ~= tabRope;

            }

        // Insert a space
        else foreach (i; 0 .. indentLevel) {

            result ~= spaceRope[0 .. indentWidth];

        }

        return result;

    }

    /// `indentRope` outputs tabs if .useTabs is set.
    @("CodeInput.indentRope outputs tabs")
    unittest {

        auto root = codeInput(.useTabs);

        assert(root.indentRope == "\t");
        assert(root.indentRope(2) == "\t\t");
        assert(root.indentRope(3) == "\t\t\t");

    }

    /// `indentRope` outputs series of spaces if spaces are used for indents. This is the default behavior.
    @("CodeInput.indentRope outputs spaces")
    unittest {

        auto root = codeInput();

        assert(root.indentRope == "    ");
        assert(root.indentRope(2) == "        ");
        assert(root.indentRope(3) == "            ");

    }

    protected void reparse() {

        const fullValue = sourceValue;

        // Parse the file
        if (highlighter) {

            highlighter.parse(fullValue);

            // Apply highlighting to the label
            contentLabel.text.styleMap = highlighter.save(cast(int) prefix.length);

        }

        // Pass the file to the indentor
        if (indentor && cast(Object) indentor !is cast(Object) highlighter) {

            indentor.parse(fullValue);

        }

    }

    override void resizeImpl(Vector2 vector) @trusted {

        // Parse changes
        reparse();

        // Reformat the line if requested
        if (_automaticFormat.pending) {

            const oldTarget = _automaticFormat.oldTargetIndent;
            const newTarget = targetIndentLevelByIndex(caretIndex);

            // Reformat only if the target indent changed; don't force "correct" indents on the programmer
            if (oldTarget != newTarget)
                reformatLine();

            _automaticFormat.pending = false;

        }

        // Resize the field
        super.resizeImpl(vector);

    }

    override void drawImpl(Rectangle outer, Rectangle inner) {

        // Reload token styles
        contentLabel.styles[0] = pickStyle();

        if (highlighter) {

            CodeToken tokenIndex;
            while (++tokenIndex) {

                token = highlighter.nextTokenName(tokenIndex);

                if (token is null) break;

                contentLabel.styles[tokenIndex] = pickStyle();

            }

        }

        super.drawImpl(outer, inner);

    }

    protected override bool keyboardImpl() {

        auto oldValue = this.value;
        auto format = AutomaticFormat(targetIndentLevelByIndex(caretIndex));

        auto keyboardHandled = super.keyboardImpl();

        // If the value has changed, trigger automatic reformatting
        if (oldValue !is this.value)
            _automaticFormat = format;

        return keyboardHandled;

    }

    protected override bool inputActionImpl(InputActionID id, bool active) {

        // Request format
        if (active)
            _automaticFormat = AutomaticFormat(targetIndentLevelByIndex(caretIndex));

        return false;

    }

    /// Returns the index of the first character in a line that is not a space, given index of any character on
    /// the same line.
    size_t lineHomeByIndex(size_t index) {

        const indentWidth = lineByIndex(index)
            .until!(a => !a.among(' ', '\t'))
            .walkLength;

        return lineStartByIndex(index) + indentWidth;

    }

    /// Get the column the given index (or caret index) is at, but count tabs as however characters they display as.
    ptrdiff_t visualColumn(size_t i) {

        // Select characters on the same before the given index
        auto indents = lineByIndex(i)[0 .. column!char(i)];

        return foldIndents(indents);

    }

    /// ditto
    ptrdiff_t visualColumn() {

        return visualColumn(caretIndex);

    }

    /// Get indent count for offset at given index.
    int indentLevelByIndex(size_t i) {

        // Select indents on the given line
        auto indents = lineByIndex(i).byDchar
            .until!(a => !a.among(' ', '\t'));

        return cast(int) foldIndents(indents) / indentWidth;

    }

    /// Count width of the given text, counting tabs using their visual size, while other characters are of width of 1
    private auto foldIndents(T)(T input) {

        return input.fold!(
            (a, c) => c == '\t'
                ? a + indentWidth - (a % indentWidth)
                : a + 1)(0);

    }

    /// Get suitable indent size for the line at given index, according to information from `indentor`.
    int targetIndentLevelByIndex(size_t i) {

        const lineStart = lineStartByIndex(i);

        // Find the previous line so it can be used as reference.
        // For the first line, `0` is used.
        const untilPreviousLine = value[0..lineStart].chomp;
        const previousLineIndent = lineStart == 0
            ? 0
            : indentLevelByIndex(untilPreviousLine.length);

        // Use the indentor if available
        if (indentor) {

            const indentEnd = lineHomeByIndex(i);

            return max(0, previousLineIndent + indentor.indentDifference(indentEnd + prefix.length));

        }

        // Perform basic autoindenting if indentor is not available; keep the same indent at all time
        else return indentLevelByIndex(i);

    }

    @(FluidInputAction.insertTab)
    void insertTab() {

        // Indent selection
        if (isSelecting) indent();

        // Insert a tab character
        else if (useTabs) {

            push('\t');

        }

        // Align to tab
        else {

            char[maxIndentWidth] insertTab = ' ';

            const newSpace = indentWidth - (column!dchar % indentWidth);

            push(insertTab[0 .. newSpace]);

        }

    }

    @(FluidInputAction.indent)
    void indent() {

        indent(1);

    }

    void indent(int indentCount, bool includeEmptyLines = false) {

        // Write an undo/redo history entry
        auto shot = snapshot();
        scope (success) pushSnapshot(shot);

        // Indent every selected line
        foreach (ref line; eachSelectedLine) {

            // Skip empty lines
            if (!includeEmptyLines && line == "") continue;

            // Prepend the indent
            line = indentRope(indentCount) ~ line;

        }

    }

    @(FluidInputAction.outdent)
    void outdent() {

        outdent(1);

    }

    void outdent(int i) {

        // Write an undo/redo history entry
        auto shot = snapshot();
        scope (success) pushSnapshot(shot);

        // Outdent every selected line
        foreach (ref line; eachSelectedLine) {

            // Do it for each indent
            foreach (j; 0..i) {

                const leadingWidth = line.take(indentWidth)
                    .until!(a => !a.among(' ', '\t'))
                    .until("\t", No.openRight)
                    .walkLength;

                // Remove the tab
                line = line[leadingWidth .. $];

            }

        }

    }

    override void chop(bool forward = false) {

        // Make it possible to backspace space-based indents
        if (!forward && !isSelecting) {

            const lineStart = lineStartByIndex(caretIndex);
            const lineHome = lineHomeByIndex(caretIndex);
            const isIndent = caretIndex > lineStart && caretIndex <= lineHome;

            // This is an indent
            if (isIndent) {

                const line = caretLine;
                const col = column!char;
                const tabWidth = either(visualColumn % indentWidth, indentWidth);
                const tabStart = max(0, col - tabWidth);
                const allSpaces = line[tabStart .. col].all!(a => a == ' ');

                // Remove spaces as if they were tabs
                if (allSpaces) {

                    const oldCaretIndex = caretIndex;

                    // Write an undo/redo history entry
                    auto shot = snapshot();
                    scope (success) pushSnapshot(shot);

                    caretLine = line[0 .. tabStart] ~ line[col .. $];
                    caretIndex = oldCaretIndex - tabWidth;

                    return;

                }

            }

        }

        super.chop(forward);

    }

    @(FluidInputAction.breakLine)
    override bool breakLine() {

        const currentIndent = indentLevelByIndex(caretIndex);

        // Break the line
        if (super.breakLine()) {

            // Copy indent from the previous line
            // Enable continuous input to merge the indent with the line break in the history
            _isContinuous = true;
            push(indentRope(currentIndent));
            reparse();

            // Ask the autoindentor to complete the job
            reformatLine();
            _isContinuous = false;

            return true;

        }

        return false;

    }

    /// Reformat a line by index of any character it contains.
    void reformatLineByIndex(size_t index) {

        import std.math;

        // TODO Implement reformatLine for selections
        if (isSelecting) return;

        const newIndentLevel = targetIndentLevelByIndex(index);

        const line = lineByIndex(index);
        const lineStart = lineStartByIndex(index);
        const lineHome = lineHomeByIndex(index);
        const lineEnd = lineEndByIndex(index);
        const newIndent = indentRope(newIndentLevel);
        const oldIndentLength = lineHome - lineStart;

        // Ignore if indent is the same
        if (newIndent.length == oldIndentLength) return;

        const oldCaretIndex = caretIndex;
        const newLine = newIndent ~ line[oldIndentLength .. $];

        // Write the new indent, replacing the old one
        lineByIndex(index, newLine);

        // Update caret index
        if (oldCaretIndex >= lineStart && oldCaretIndex <= lineEnd)
            caretIndex = clamp(oldCaretIndex + newIndent.length - oldIndentLength,
                lineStart + newIndent.length,
                lineStart + newLine.length);

        // Parse again
        reparse();

    }

    /// Reformat the current line.
    void reformatLine() {

        reformatLineByIndex(caretIndex);

    }

    /// CodeInput moves `toLineStart` action handler to `toggleHome`
    override void caretToLineStart() {

        super.caretToLineStart();

    }

    /// Move the caret to the "home" position of the line, see `lineHomeByIndex`.
    void caretToLineHome() {

        caretIndex = lineHomeByIndex(caretIndex);
        updateCaretPosition(true);
        moveOrClearSelection();
        horizontalAnchor = caretPosition.x;

    }

    /// Move the caret to the "home" position of the line — or if the caret is already at that position, move it to
    /// line start. This function perceives the line visually, so if the text wraps, it will go to the beginning of the
    /// visible line, instead of the hard line break or the home.
    ///
    /// See_Also: `caretToLineHome` and `lineHomeByIndex`
    @(FluidInputAction.toLineStart)
    void toggleHome() {

        const home = lineHomeByIndex(caretIndex);
        const oldIndex = caretIndex;

        // Move to visual start of line
        caretToLineStart();

        const shouldMove = caretIndex < home
            || caretIndex == oldIndex;

        // Unless the caret was already at home, or it didn't move to start, navigate home
        if (oldIndex != home && shouldMove) {

            caretToLineHome();

        }

    }

    @(FluidInputAction.paste)
    override void paste() {

        import std.array : Appender;

        if (clipboardIO) {

            char[1024] buffer;
            Appender!(char[]) content;
            int offset;

            // Read text from the clipboard and into the buffer
            // This is not the most optimal, but pasting is completely reworked in the next release anyway
            while (true) {
                if (auto text = clipboardIO.readClipboard(buffer, offset)) {
                    content ~= text;
                }
                else break;
            }

            paste(content[]);

        }
        else {
            paste(io.clipboard);
        }

    }

    void paste(const char[] clipboard) {

        import fluid.typeface : Typeface;

        // Write an undo/redo history entry
        auto shot = snapshot();
        scope (success) forcePushSnapshot(shot);

        const pasteStart = selectionLowIndex;
        auto indentLevel = indentLevelByIndex(pasteStart);

        // Find the smallest indent in the clipboard
        // Skip the first line because it's likely to be without indent when copy-pasting
        auto lines = Typeface.lineSplitter(clipboard).drop(1);

        // Count indents on each line, skip blank lines
        auto significantIndents = lines
            .map!(a => a
                .countUntil!(a => !a.among(' ', '\t')))
            .filter!(a => a != -1);

        // Test blank lines only if all lines are blank
        const commonIndent
            = !significantIndents.empty ? significantIndents.minElement()
            : !lines.empty ? lines.front.length
            : 0;

        // Remove the common indent
        auto outdentedClipboard = Typeface.lineSplitter!(Yes.keepTerminator)(clipboard)
            .map!((a) {
                const localIndent = a
                    .until!(a => !a.among(' ', '\t'))
                    .walkLength;

                return a.drop(min(commonIndent, localIndent));
            })
            .map!(a => Rope(a))
            .array;

        // Push the clipboard
        push(Rope.merge(outdentedClipboard));

        reparse();

        const pasteEnd = caretIndex;

        // Reformat each line
        foreach (index, ref line; eachLineByIndex(pasteStart, pasteEnd)) {

            // Save indent of the first line, but don't reformat
            // `min` is used in case text is pasted inside the indent
            if (index <= pasteStart) {
                indentLevel = min(indentLevel, indentLevelByIndex(pasteStart));
                continue;
            }

            // Use the reformatter if available
            if (indentor) {
                reformatLineByIndex(index);
                line = lineByIndex(index);
            }

            // If not, prepend the indent
            else {
                line = indentRope(indentLevel) ~ line;
            }

        }

        // Make sure the input is parsed completely
        reparse();

    }
    @("CodeInput calls parse only once if Highlighter and Indentor are the same")
    unittest {

        import std.typecons;

        static abstract class Highlighter : CodeHighlighter {

            int highlightCount;

            void parse(Rope) {
                highlightCount++;
            }

        }

        static abstract class Indentor : CodeIndentor {

            int indentCount;

            void parse(Rope) {
                indentCount++;
            }

        }

        auto highlighter = new BlackHole!Highlighter;
        auto root = codeInput(highlighter);
        root.reparse();

        assert(highlighter.highlightCount == 1);

        auto indentor = new BlackHole!Indentor;
        root.indentor = indentor;
        root.reparse();

        // Parse called once for each
        assert(highlighter.highlightCount == 2);
        assert(indentor.indentCount == 1);

        static abstract class FullHighlighter : CodeHighlighter, CodeIndentor {

            int highlightCount;
            int indentCount;

            void parse(Rope) {
                highlightCount++;
                indentCount++;
            }

        }

        auto fullHighlighter = new BlackHole!FullHighlighter;
        root = codeInput(fullHighlighter);
        root.reparse();

        // Parse should be called once for the whole class
        assert(fullHighlighter.highlightCount == 1);
        assert(fullHighlighter.indentCount == 1);

    }

    @("Legacy: CodeInput.paste creates a history entry (migrated)")
    unittest {

        auto io = new HeadlessBackend;
        auto root = codeInput(.useSpaces(2));
        root.io = io;

        io.clipboard = "World";
        root.push("  Hello,");
        root.runInputAction!(FluidInputAction.breakLine);
        root.paste();
        assert(!root._isContinuous);
        root.push("!");
        assert(root.value == "  Hello,\n  World!");

        // Undo the exclamation mark
        root.undo();
        assert(root.value == "  Hello,\n  World");

        // Undo moves before pasting
        root.undo();
        assert(root.value == "  Hello,\n  ");
        assert(root.valueBeforeCaret == root.value);

        // Next undo moves before line break
        root.undo();
        assert(root.value == "  Hello,");

        // Next undo clears all changes
        root.undo();
        assert(root.value == "");

        // No change
        root.undo();
        assert(root.value == "");

        // It can all be redone
        root.redo();
        assert(root.value == "  Hello,");
        assert(root.valueBeforeCaret == root.value);
        root.redo();
        assert(root.value == "  Hello,\n  ");
        assert(root.valueBeforeCaret == root.value);
        root.redo();
        assert(root.value == "  Hello,\n  World");
        assert(root.valueBeforeCaret == root.value);
        root.redo();
        assert(root.value == "  Hello,\n  World!");
        assert(root.valueBeforeCaret == root.value);
        root.redo();
        assert(root.value == "  Hello,\n  World!");

    }

}

///
unittest {

    // Start a code editor
    codeInput();

    // Start a code editor that uses tabs
    codeInput(
        .useTabs
    );

    // Or, 2 spaces, if you prefer — the default is 4 spaces
    codeInput(
        .useSpaces(2)
    );

}

alias CodeToken = ubyte;
alias CodeSlice = TextStyleSlice;

// Note: This was originally a member of CodeHighlighter, but it broke the vtable sometimes...? I wasn't able to
// produce a minimal example to open a bug ticket, sorry.
alias CodeHighlighterRange = typeof(CodeHighlighter.save());

/// Implements syntax highlighting for `CodeInput`.
/// Warning: This API is unstable and might change without warning.
interface CodeHighlighter {

    /// Get a name for the token at given index. Returns null if there isn't a token at given index. Indices must be
    /// sequential. Starts at 1.
    const(char)[] nextTokenName(CodeToken index);

    /// Parse the given text to use with other functions in the highlighter.
    void parse(Rope text);

    /// Find the next important range starting with the byte at given index.
    ///
    /// Tip: Query is likely to be called again with `byteIndex` set to the value of `range.end`.
    ///
    /// Returns:
    ///     The next relevant code range. Parts with no highlighting should be ignored. If there is nothing left to
    ///     highlight, should return `init`.
    CodeSlice query(size_t byteIndex)
    in (byteIndex != size_t.max, "Invalid byte index (-1)")
    out (r; r.end != byteIndex, "query() must not return empty ranges");

    /// Produce a TextStyleSlice range using the result.
    /// Params:
    ///     offset = Number of bytes to skip. Apply the offset to all resulting items.
    /// Returns: `CodeHighlighterRange` suitable for use as a `Text` style map.
    final save(int offset = 0) {

        static struct HighlighterRange {

            CodeHighlighter highlighter;
            TextStyleSlice front;
            int offset;

            bool empty() const {

                return front is front.init;

            }

            // Continue where the last token ended
            void popFront() {

                do front = highlighter.query(front.end + offset).offset(-offset);

                // Pop again if got a null token
                while (front.styleIndex == 0 && front !is front.init);

            }

            HighlighterRange save() {

                return this;

            }

        }

        return HighlighterRange(this, query(offset).offset(-offset), offset);

    }

}

interface CodeIndentor {

    /// Parse the given text.
    void parse(Rope text);

    /// Get indent level for the given offset, relative to the previous line.
    ///
    /// `CodeInput` will use the first non-white character on a line as a reference for reformatting.
    int indentDifference(ptrdiff_t offset);

}
