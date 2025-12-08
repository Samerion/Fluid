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
import fluid.text.typeface;


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

    // 64 spaces of indent ought to be more than anyone should ever need
    static protected const maxIndentTabs = "\t\t\t\t\t\t\t\t";
    static protected const maxIndentSpaces
        = "                                                                ";
    enum maxIndentWidth = maxIndentSpaces.length;

    static assert((maxIndentWidth  & (maxIndentWidth  - 1)) == 0,
        "maxIndentSpaces must be a power of two.");
    static assert(maxIndentTabs.length * 8 == maxIndentSpaces.length);

    public {

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

        Rope _prefix;
        Rope _suffix;
        TextInterval _prefixInterval;

        /// Boundaries of the range that was edited single the last call to `reparse`.
        TextInterval _reparseRangeStart, _reparseRangeOldEnd, _reparseRangeNewEnd;

        CodeHighlighter _highlighter;

    }

    this(CodeHighlighter highlighter = null, void delegate() @safe submitted = null) {

        super.contentLabel = new ContentLabel;
        this.submitted = submitted;
        this.highlighter = highlighter;

    }

    inout(ContentLabel) contentLabel() inout {

        return cast(inout ContentLabel) super.contentLabel;

    }

    override size_t nearestCharacter(Vector2 needle) {

        return contentLabel.text.indexAt(needle);

    }

    override TextRuler rulerAt(size_t index, bool preferNextLine = false) {

        return contentLabel.text.rulerAt(index, preferNextLine);

    }

    override TextInterval intervalAt(size_t index) {

        return contentLabel.text.intervalAt(index);

    }

    override CachedTextRuler rulerAtPosition(Vector2 position) {

        return contentLabel.text.rulerAtPosition(position);

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

        protected override inout(Rope) value() inout {
            return text;
        }

        protected override void replace(size_t start, size_t end, Rope value) {
            text.replace(start, end, value);
        }

        override void resizeImpl(Vector2 available) {

            assert(text.hasFastEdits);

            use(canvasIO);

            auto typeface = style.getTypeface;
            typeface.setSize(io.dpi, style.fontSize);

            text.indentWidth = indentWidth * typeface.advance(' ').x / io.hidpiScale.x;
            text.resize(available);
            placeholderText.resize(available);

            minSize.x = max(placeholderText.size.x, text.size.x);
            minSize.y = max(placeholderText.size.y, text.size.y);

            assert(this.text.isMeasured);

        }

        override void drawImpl(Rectangle outer, Rectangle inner) {

            const style = pickStyle();
            if (showPlaceholder)
                placeholderText.draw(canvasIO, styles, inner.start);
            else
                text.draw(canvasIO, styles, inner.start);

        }

    }

    /// Additional context to pass to the highlighter. Will not be displayed, but can be used to improve syntax
    /// highlighting and code analysis.
    Rope prefix() const {
        return _prefix;
    }

    Rope prefix(Rope newValue) {
        _prefixInterval = TextInterval(newValue);
        return _prefix = newValue;
    }

    /// ditto
    Rope suffix() const {
        return _suffix;
    }

    Rope suffix(Rope newValue) {
        return _suffix = newValue;
    }

    /// Get the full value of the text, including context provided via `prefix` and `suffix`.
    Rope sourceValue() const {

        // TODO This will allocate. Can it be avoided?
        return prefix ~ value ~ suffix;

    }

    /// Get or set the current code highlighter.
    inout(CodeHighlighter) highlighter() inout {
        return _highlighter;
    }

    /// ditto
    CodeHighlighter highlighter(CodeHighlighter highlighter) {

        // Set the reparse range
        _reparseRangeStart = TextInterval.init;
        _reparseRangeOldEnd = intervalAt(value.length);
        _reparseRangeNewEnd = intervalAt(value.length);

        return _highlighter = highlighter;
    }

    /// Returns: A rope representing given indent level.
    Rope indentRope(int indentLevel = 1) const {

        // TODO this could be smarter by precalculating the rope's size
        return indentRange(indentLevel)
            .map!(a => Rope(a))
            .fold!((a, b) => a ~ b)(Rope.init);

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

    /// Returns:
    ///     A range of strings, which if concatenated, would create the requested indent with the current
    ///     indent settings.
    /// Params:
    ///     indentLevel = Number of indent
    ///     column = Current column in the text. If spaces are used, the number of spaces will complement the column
    ///         so that it is a multiple of `indentWidth`.
    auto indentRange(ptrdiff_t indentLevel = 1, ptrdiff_t column = 0) const {

        const characterCount = useTabs
            ? indentLevel
            : indentLevel * indentWidth - column % indentWidth;
        const maxCharacterCount = useTabs
            ? maxIndentTabs.length
            : maxIndentSpaces.length;

        // Indents are created by slicing either `maxIndentTabs` or `maxIndentSpaces`, which are limited in size.
        // In case an indent is larger than the size of either, it has to be split into multiple parts, which is
        // why this function returns a range of strings, rather than characters.
        // The `iota` range will count down the number of characters remaining to print, including the count,
        // excluding the zero.
        return iota(characterCount, 0, -cast(ptrdiff_t) maxCharacterCount)

            // Map each item to a slice with the needed number of characters.
            .map!(a => useTabs
                ? maxIndentTabs[0 .. min(a, maxIndentTabs.length)]
                : maxIndentSpaces[0 .. min(a, maxIndentSpaces.length)]);

    }

    ///
    unittest {

        auto root = codeInput();

        assert(root.indentRange()    .equal(["    "]));      // 4 spaces
        assert(root.indentRange(2)   .equal(["        "]));  // 8 spaces
        assert(root.indentRange(2, 3).equal(["     "]));     // 5 spaces (8-3)
        assert(root.indentRange(2, 6).equal(["      "]));    // 6 spaces (8-2)
        assert(root.indentRange(100).joiner.walkLength == 100 * 4);
        assert(root.indentRange(100, 1).joiner.walkLength == 100 * 4 - 1);
        assert(root.indentRange(100, 3).joiner.walkLength == 100 * 4 - 3);
        assert(root.indentRange(100, 4).joiner.walkLength == 100 * 4);

        root.useTabs = true;

        assert(root.indentRange()    .equal(["\t"]));
        assert(root.indentRange(2)   .equal(["\t\t"]));
        assert(root.indentRange(2, 3).equal(["\t\t"]));
        assert(root.indentRange(2, 6).equal(["\t\t"]));
        assert(root.indentRange(100)   .joiner.walkLength == 100);
        assert(root.indentRange(100, 5).joiner.walkLength == 100);

    }

    protected override bool replace(size_t start, size_t end, Rope added, bool isMinor) {

        const startInterval  = intervalAt(start);
        const oldEndInterval = intervalAt(end);

        const hasReplaced = super.replace(start, end, added, isMinor);

        const newEndInterval = intervalAt(start + added.length);

        // Mark the range for reparsing
        queueReparse(startInterval, oldEndInterval, newEndInterval);

        // Perform the replace
        return hasReplaced;

    }

    /// Reparse changes made to the text immediately.
    protected void reparse() {

        if (!highlighter) return;

        const offset = _prefixInterval;
        const start  = offset + _reparseRangeStart;
        const oldEnd = offset + _reparseRangeOldEnd;
        const newEnd = offset + _reparseRangeNewEnd;
        const fullValue = sourceValue;

        resetReparseRange();

        // Parse the file
        if (highlighter) {

            highlighter.parse(fullValue, start, oldEnd, newEnd);

        }

    }

    /// Add a range to update when calling `reparse` or before resize.
    /// Params:
    ///     start  = Interval from start of text to start of the range to be reparsed.
    ///     oldEnd = Interval from start of text to the end of the range before changes (removed text).
    ///     newEnd = Interval from start of text to end of the range after changes (added text).
    protected void queueReparse(TextInterval start, TextInterval oldEnd, TextInterval newEnd) {

        const isInit = _reparseRangeStart is _reparseRangeStart.init
            && _reparseRangeOldEnd is _reparseRangeOldEnd.init
            && _reparseRangeNewEnd is _reparseRangeNewEnd.init;

        // If the current reparse range is empty, it should be replaced
        if (isInit) {

            _reparseRangeStart = start;
            _reparseRangeOldEnd = oldEnd;
            _reparseRangeNewEnd = newEnd;
            return;

        }

        // There are two ranges that result from the three values:
        // * start .. oldEnd
        // * start .. newEnd
        // The range resulting from the reparse is the union of the previously known range, and the new range.
        // * min(_reparseRangeStart, start) .. max(_reparseRangeOldEnd, oldEnd)
        // * min(_reparseRangeStart, start) .. max(_reparseRangeNewEnd, oldEnd)
        if (start.length < _reparseRangeStart.length)
            _reparseRangeStart = start;
        if (oldEnd.length > _reparseRangeOldEnd.length)
            _reparseRangeOldEnd = oldEnd;
        if (newEnd.length > _reparseRangeNewEnd.length)
            _reparseRangeNewEnd = newEnd;

    }

    private void resetReparseRange() {

        _reparseRangeStart  = TextInterval.init;
        _reparseRangeOldEnd = TextInterval.init;
        _reparseRangeNewEnd = TextInterval.init;

    }

    unittest {

        import std.typecons;

        static abstract class Highlighter : CodeHighlighter {

            int highlightCount;

            void parse(Rope, TextInterval, TextInterval, TextInterval) {
                highlightCount++;
            }

        }

        auto highlighter = new BlackHole!Highlighter;
        auto root = codeInput(highlighter);
        root.reparse();

        assert(highlighter.highlightCount == 1);

    }

    override void resizeImpl(Vector2 vector) @trusted {

        // Resize the field
        super.resizeImpl(vector);

        // Update syntax highlighting:
        if (highlighter) {

            reparse();

            // Apply highlighting to the label
            contentLabel.text.styleMap = highlighter.save(cast(int) prefix.length);

        }

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

    unittest {

        auto root = codeInput();
        root.value = "    ą bcd";

        foreach (i; 0 .. root.value.length) {
            assert(root.visualColumn(i) == i);
        }

        root.value = "\t \t  \t   \t\n";
        assert(root.visualColumn(0) == 0);   // 0 spaces, tab
        assert(root.visualColumn(1) == 4);   // 1 space, tab
        assert(root.visualColumn(2) == 5);
        assert(root.visualColumn(3) == 8);   // 2 spaces, tab
        assert(root.visualColumn(4) == 9);
        assert(root.visualColumn(5) == 10);
        assert(root.visualColumn(6) == 12);  // 3 spaces, tab
        assert(root.visualColumn(7) == 13);
        assert(root.visualColumn(8) == 14);
        assert(root.visualColumn(9) == 15);
        assert(root.visualColumn(10) == 16);  // Line feed
        assert(root.visualColumn(11) == 0);

    }

    /// Params:
    ///     index = Index of any character on the target line.
    /// Returns:
    ///     Rope containing the indent on that line.
    Rope indentByIndex(size_t index) const {

        // Select indents on the given line
        const line = lineByIndex(index);
        const length = line.byChar
            .until!(a => !a.among(' ', '\t'))
            .walkLength;

        return line[0 .. length];

    }

    /// Get indent count for offset at given index.
    int indentLevelByIndex(size_t i) const {

        // Select indents on that line
        auto indents = indentByIndex(i).byChar;

        return cast(int) foldIndents(indents) / indentWidth;

    }

    /// Count width of the given text, counting tabs using their visual size, while other characters are of width of 1
    private size_t foldIndents(T)(T input) const {

        return input.fold!(
            (a, c) => c == '\t'
                ? a + indentWidth - (a % indentWidth)
                : a + 1)(0);

    }

    unittest {

        auto root = codeInput();
        root.value = "hello,    \n"
            ~ "  world    a\n"
            ~ "    \n"
            ~ "    foo\n"
            ~ "     world\n"
            ~ "        world\n";

        assert(root.indentLevelByIndex(0) == 0);
        assert(root.indentLevelByIndex(11) == 0);
        assert(root.indentLevelByIndex(24) == 1);
        assert(root.indentLevelByIndex(29) == 1);
        assert(root.indentLevelByIndex(37) == 1);
        assert(root.indentLevelByIndex(48) == 2);

    }

    unittest {

        auto root = codeInput();
        root.value = "hello,\t\n"
            ~ "  world\ta\n"
            ~ "\t\n"
            ~ "\tfoo\n"
            ~ "   \t world\n"
            ~ "\t\tworld\n";

        assert(root.indentLevelByIndex(0) == 0);
        assert(root.indentLevelByIndex(8) == 0);
        assert(root.indentLevelByIndex(18) == 1);
        assert(root.indentLevelByIndex(20) == 1);
        assert(root.indentLevelByIndex(25) == 1);
        assert(root.indentLevelByIndex(36) == 2);

    }

    /// Action handler for the tab key.
    @(FluidInputAction.insertTab)
    void insertTab() {

        const isMinor = true;

        insertTab(1, isMinor);

    }

    void insertTab(int indentLevel, bool isMinor = true) {

        // Indent selection
        if (isSelecting) indent(indentLevel);

        // Insert a tab character
        else foreach (fragment; indentRange(indentLevel, column!dchar)) {

            super.push(fragment, isMinor);

        }

    }

    @("CodeInput.insertTab creates aligned spaces/simulates tab behavior")
    unittest {

        auto root = codeInput();
        root.insertTab();
        assert(root.value == "    ");
        root.push("aa");
        root.insertTab();
        assert(root.value == "    aa  ");
        root.insertTab();
        assert(root.value == "    aa      ");
        root.rawPush("\n");
        root.insertTab();
        assert(root.value == "    aa      \n    ");
        root.insertTab();
        assert(root.value == "    aa      \n        ");
        root.push("||");
        root.insertTab();
        assert(root.value == "    aa      \n        ||  ");

    }

    @("CodeInput: Tabs are aligned also when inserting multiples of them")
    unittest {

        auto root = codeInput(
            .useSpaces(4),
        );
        root.push("  ");
        root.insertTab(2);
        assert(root.value.length == 8);

        root.insertTab(60);
        assert(root.value.length == 8 + 60*4);
        assert(root.value.all!(a => a == ' '));

    }

    unittest {

        auto root = codeInput(.useSpaces(2));
        root.insertTab();
        assert(root.value == "  ");
        root.push("aa");
        root.insertTab();
        assert(root.value == "  aa  ");
        root.insertTab();
        assert(root.value == "  aa    ");
        root.rawPush("\n");
        root.insertTab();
        assert(root.value == "  aa    \n  ");
        root.insertTab();
        assert(root.value == "  aa    \n    ");
        root.push("||");
        root.insertTab();
        assert(root.value == "  aa    \n    ||  ");
        root.push("x");
        root.insertTab();
        assert(root.value == "  aa    \n    ||  x ");

    }

    unittest {

        auto root = codeInput(.useTabs);
        root.insertTab();
        assert(root.value == "\t");
        root.push("aa");
        root.insertTab();
        assert(root.value == "\taa\t");
        root.insertTab();
        assert(root.value == "\taa\t\t");
        root.rawPush("\n");
        root.insertTab();
        assert(root.value == "\taa\t\t\n\t");
        root.insertTab();
        assert(root.value == "\taa\t\t\n\t\t");
        root.push("||");
        root.insertTab();
        assert(root.value == "\taa\t\t\n\t\t||\t");

    }

    unittest {

        const originalValue = "Fïrst line\nSëcond line\r\n Thirð\n\n line\n    Fourth line\nFifth line";

        auto root = codeInput();
        root.push(originalValue);
        root.selectionStart = 19;
        root.selectionEnd = 49;

        assert(root.lineByIndex(root.selectionStart) == "Sëcond line");
        assert(root.lineByIndex(root.selectionEnd) == "    Fourth line");

        root.insertTab();

        assert(root.value == "Fïrst line\n    Sëcond line\r\n     Thirð\n\n     line\n        Fourth line\nFifth line");
        assert(root.lineByIndex(root.selectionStart) == "    Sëcond line");
        assert(root.lineByIndex(root.selectionEnd) == "        Fourth line");

        root.outdent();

        assert(root.value == originalValue);
        assert(root.lineByIndex(root.selectionStart) == "Sëcond line");
        assert(root.lineByIndex(root.selectionEnd) == "    Fourth line");

        root.outdent();
        assert(root.value == "Fïrst line\nSëcond line\r\nThirð\n\nline\nFourth line\nFifth line");

        root.insertTab();
        assert(root.value == "Fïrst line\n    Sëcond line\r\n    Thirð\n\n    line\n    Fourth line\nFifth line");

    }

    @("CodeInput.insertTab/indent/outdent correctly interact with the history")
    unittest {

        auto root = codeInput(.useTabs);

        root.savePush("Hello, World!");
        root.runInputAction!(FluidInputAction.toStart);
        root.runInputAction!(FluidInputAction.insertTab);
        assert(root.value == "\tHello, World!");
        assert(root.valueBeforeCaret == "\t");

        root.undo();
        assert(root.value == "Hello, World!");
        assert(root.valueBeforeCaret == "");

        root.redo();
        assert(root.value == "\tHello, World!");
        assert(root.valueBeforeCaret == "\t");

        root.runInputAction!(FluidInputAction.toEnd);
        root.runInputAction!(FluidInputAction.outdent);
        assert(root.value == "Hello, World!");
        assert(root.valueBeforeCaret == root.value);
        assert(root.valueAfterCaret == "");

        root.undo();
        assert(root.value == "\tHello, World!");
        assert(root.valueBeforeCaret == root.value);

        root.undo();
        assert(root.value == "Hello, World!");
        assert(root.valueBeforeCaret == "");

        root.undo();
        assert(root.value == "");
        assert(root.valueBeforeCaret == "");

    }

    @(FluidInputAction.indent)
    void indent() {

        indent(1);

    }

    /// Indent all selected lines or the one the caret is on.
    void indent(int indentCount, bool includeEmptyLines = false) {

        if (indentCount == 0) return;

        const isMinor = true;

        // Indent every selected line
        foreach (start, line; eachSelectedLine) {

            // Skip empty lines
            if (!includeEmptyLines && line == "") continue;

            insert(start, indentRope(indentCount), isMinor);

        }

    }

    @(FluidInputAction.outdent)
    void outdent() {

        outdent(1);

    }

    void outdent(int level) {

        const isMinor = true;

        // Outdent every selected line
        foreach (start, line; eachSelectedLine) {

            // Do it for each indent
            foreach (j; 0 .. level) {

                const leadingWidth = line.take(indentWidth)
                    .until!(a => !a.among(' ', '\t'))
                    .until("\t", No.openRight)
                    .walkLength;

                replace(start, start + leadingWidth, Rope.init, isMinor);

            }

        }

    }

    @("CodeInput.outdent reduces the indent of currently selecetd lines")
    unittest {

        auto root = codeInput();
        root.outdent();
        assert(root.value == "");

        root.push("  ");
        root.outdent();
        assert(root.value == "");

        root.push("\t");
        root.outdent();
        assert(root.value == "");

        root.push("    ");
        root.outdent();
        assert(root.value == "");

        root.push("     ");
        assert(root.valueBeforeCaret == "     ");
        root.outdent();
        assert(root.value == " ");
        assert(root.valueBeforeCaret == " ");

        root.push("foobarbaz  ");
        assert(root.valueBeforeCaret == " foobarbaz  ");
        root.insertTab();
        root.outdent();
        assert(root.value == "foobarbaz      ");

        root.outdent();
        assert(root.value == "foobarbaz      ");

        root.push('\t');
        root.outdent();
        assert(root.value == "foobarbaz      \t");

        root.push("\n   abc  ");
        root.outdent();
        assert(root.value == "foobarbaz      \t\nabc  ");

        root.push("\n   \ta");
        root.outdent();
        assert(root.value == "foobarbaz      \t\nabc  \na");

        root.value = "\t    \t\t\ta";
        root.outdent();
        assert(root.value == "    \t\t\ta");

        root.outdent();
        assert(root.value == "\t\t\ta");

        root.outdent(2);
        assert(root.value == "\ta");

    }

    unittest {

        auto io = new HeadlessBackend;
        auto root = codeInput();
        root.io = io;
        root.focus();

        // Tab twice
        foreach (i; 0..2) {

            assert(root.value.length == i*4);

            io.nextFrame;
            io.press(KeyboardKey.tab);
            root.draw();

            io.nextFrame;
            io.release(KeyboardKey.tab);
            root.draw();

        }

        io.nextFrame;
        root.draw();

        assert(root.value == "        ");
        assert(root.valueBeforeCaret == "        ");

        // Outdent
        io.nextFrame;
        io.press(KeyboardKey.leftShift);
        io.press(KeyboardKey.tab);
        root.draw();

        io.nextFrame;
        root.draw();

        assert(root.value == "    ");
        assert(root.valueBeforeCaret == "    ");

    }

    unittest {

        auto root = codeInput(.useSpaces(2));
        root.value = "    abc";
        root.outdent();
        assert(root.value == "  abc");
        root.outdent();
        assert(root.value == "abc");

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

                    const isMinor = true;

                    replace(lineStart + tabStart, caretIndex, Rope.init, isMinor);
                    return;

                }

            }

        }

        super.chop(forward);

    }

    unittest {

        auto root = codeInput();
        root.value = q{
                if (condition) {
                    writeln("Hello, World!");
                }
        };
        root.runInputAction!(FluidInputAction.nextWord);
        assert(root.caretIndex == root.value.indexOf("if"));
        root.chop();
        assert(root.value == q{
            if (condition) {
                    writeln("Hello, World!");
                }
        });
        root.push(' ');
        assert(root.value == q{
             if (condition) {
                    writeln("Hello, World!");
                }
        });
        root.chop();
        assert(root.value == q{
            if (condition) {
                    writeln("Hello, World!");
                }
        });

        // Jump a word and remove two characters
        root.runInputAction!(FluidInputAction.nextWord);
        root.chop();
        root.chop();
        assert(root.value == q{
            i(condition) {
                    writeln("Hello, World!");
                }
        });

        // Push two spaces, chop one
        root.push("  ");
        root.chop();
        assert(root.value == q{
            i (condition) {
                    writeln("Hello, World!");
                }
        });

    }

    unittest {

        auto root = codeInput();
        // 2 spaces, tab, 7 spaces
        // Effectively 2.75 of an indent
        root.value = "  \t       ";
        root.caretToEnd();
        root.chop();

        assert(root.value == "  \t    ");
        root.chop();

        // Tabs are not treated specially by chop, though
        // They could be, maybe, but it's such a dumb edgecase, this should be good enough for everybody
        // (I've checked that Kate does remove this in a single chop)
        assert(root.value == "  \t");
        root.chop();
        assert(root.value == "  ");
        root.chop();
        assert(root.value == "");

        root.value = "  \t  \t  \t";
        root.caretToEnd();
        root.chop();
        assert(root.value == "  \t  \t  ");

        root.chop();
        assert(root.value == "  \t  \t");

        root.chop();
        assert(root.value == "  \t  ");

        root.chop();
        assert(root.value == "  \t");

        root.value = "\t\t\t ";
        root.caretToEnd();
        root.chop();
        assert(root.value == "\t\t\t");
        root.chop();
        assert(root.value == "\t\t");

    }

    @("CodeInput: Backspace can be works and can be undone")
    unittest {

        auto root = codeInput(.useSpaces(2));
        root.value = "      abc";
        root.caretIndex = 6;
        root.runInputAction!(FluidInputAction.backspace);
        assert(root.value == "    abc");
        root.runInputAction!(FluidInputAction.backspace);
        assert(root.value == "  abc");
        root.runInputAction!(FluidInputAction.backspace);
        assert(root.value == "abc");
        root.runInputAction!(FluidInputAction.backspace);
        assert(root.value == "abc");

        root.undo();
        assert(root.value == "      abc");
        assert(root.valueAfterCaret == "abc");


    }

    @("CodeInput.breakLine continues the indent")
    unittest {

        auto root = codeInput();

        root.savePush("abcdef");
        root.runInputAction!(FluidInputAction.breakLine);
        assert(root.value == "abcdef\n");

        root.runInputAction!(FluidInputAction.insertTab);
        root.runInputAction!(FluidInputAction.breakLine);
        assert(root.value == "abcdef\n    \n    ");

        root.runInputAction!(FluidInputAction.insertTab);
        root.runInputAction!(FluidInputAction.breakLine);
        assert(root.value == "abcdef\n    \n        \n        ");

        root.runInputAction!(FluidInputAction.outdent);
        root.runInputAction!(FluidInputAction.outdent);
        assert(root.value == "abcdef\n    \n        \n");

        root.runInputAction!(FluidInputAction.breakLine);
        assert(root.value == "abcdef\n    \n        \n\n");

        root.undo();
        assert(root.value == "abcdef\n    \n        \n");
        root.undo();
        assert(root.value == "abcdef\n    \n        \n        ");
        root.undo();
        assert(root.value == "abcdef\n    \n        ");
        root.undo();
        assert(root.value == "abcdef\n    \n    ");
        root.undo();
        assert(root.value == "abcdef\n    ");

    }

    unittest {

        auto root = codeInput(.useSpaces(2));
        root.push("abcdef\n");
        root.insertTab;
        assert(root.caretLine == "  ");
        root.breakLine();
        assert(root.caretLine == "  ");
        root.breakLine();
        root.push("a");
        assert(root.caretLine == "  a");

        assert(root.value == "abcdef\n  \n  \n  a");

    }

    unittest {

        auto root = codeInput();
        root.value = "    abcdef";
        root.caretIndex = 8;
        root.breakLine;
        assert(root.value == "    abcd\n    ef");

    }

    /// Convert indent on a line to use tabs or spaces depending on settings.
    void reformatLineByIndex(size_t index) {

        import std.math;

        // TODO Implement reformatLine for selections
        if (isSelecting) return;

        const lineStart = lineStartByIndex(index);
        const indent = indentByIndex(index);
        const indentLevel = indentLevelByIndex(index);

        const newIndent = indentRope(indentLevel);

        // No change
        if (indent == newIndent) return;

        const isMinor = true;
        const oldCaretIndex = caretIndex;
        const start = lineStart;
        const oldEnd = start + indent.length;
        const newEnd = start + newIndent.length;

        replace(start, oldEnd, newIndent, isMinor);

        // Update caret index
        if (oldCaretIndex > start && oldCaretIndex <= oldEnd) {
            setCaretIndexNoHistory(newEnd);
        }

    }

    void reformatLine() {

        reformatLineByIndex(caretIndex);

    }

    unittest {

        auto root = codeInput();

        // 3 tabs -> 3 indents
        root.push("\t\t\t");
        root.breakLine();
        assert(root.value == "\t\t\t\n            ");

        // mixed tabs (8 width total) -> 2 indents
        root.value = "  \t  \t";
        root.caretToEnd();
        root.breakLine();
        assert(root.value == "  \t  \t\n        ");

        // 6 spaces -> 1 indent
        root.value = "      ";
        root.breakLine();
        assert(root.value == "      \n    ");

        // Same but now with tabs
        root.useTabs = true;
        root.reformatLine;
        assert(root.indentRope(1) == "\t");
        assert(root.value == "      \n\t");

        // 3 tabs -> 3 indents
        root.value = "\t\t\t";
        root.breakLine();
        assert(root.value == "\t\t\t\n\t\t\t");

        // mixed tabs (8 width total) -> 2 indents
        root.value = "  \t  \t";
        root.breakLine();
        assert(root.value == "  \t  \t\n\t\t");

        // Same but now with 2 spaces
        root.useTabs = false;
        root.indentWidth = 2;
        root.reformatLine;
        assert(root.indentRope(1) == "  ");
        assert(root.value == "  \t  \t\n    ");

        // 3 tabs -> 3 indents
        root.value = "\t\t\t\n";
        root.caretToStart;
        root.reformatLine;
        assert(root.value == "      \n");

        // mixed tabs (8 width total) -> 2 indents
        root.value = "  \t  \t";
        root.caretToEnd;
        root.breakLine();
        assert(root.value == "  \t  \t\n        ");

        // 6 spaces -> 3 indents
        root.value = "      ";
        root.breakLine();
        assert(root.value == "      \n      ");

    }

    /// CodeInput moves `toLineStart` action handler to `toggleHome`
    override void caretToLineStart() {

        super.caretToLineStart();

    }

    /// Move the caret to the "home" position of the line, see `lineHomeByIndex`.
    void caretToLineHome() {

        caretIndex = lineHomeByIndex(caretIndex);
        updateCaretPositionAndAnchor(true);
        moveOrClearSelection();

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

    unittest {

        auto root = codeInput();
        root.value = "int main() {\n    return 0;\n}";
        root.caretIndex = root.value.countUntil("return");
        root.draw();
        assert(root.caretIndex == root.lineHomeByIndex(root.caretIndex));

        const home = root.caretIndex;

        // Toggle home should move to line start, because the cursor is already at home
        root.toggleHome();
        assert(root.caretIndex == home - 4);
        assert(root.caretIndex == root.lineStartByIndex(home));

        // Toggle again
        root.toggleHome();
        assert(root.caretIndex == home);

        // Move one character left
        root.caretIndex = root.caretIndex - 1;
        assert(root.caretIndex != home);
        root.toggleHome();
        root.draw();
        assert(root.caretIndex == home);

        // Move to first line and see if toggle home works well even if there's no indent
        root.caretIndex = 4;
        root.updateCaretPosition();
        root.toggleHome();
        assert(root.caretIndex == 0);

        root.toggleHome();
        assert(root.caretIndex == 0);

        // Switch to tabs
        const previousValue = root.value;
        root.useTabs = true;
        root.reformatLine();
        assert(root.value == previousValue);

        // Move to line below
        root.runInputAction!(FluidInputAction.nextLine);
        root.toggleHome();
        root.reformatLine();
        assert(root.value == "int main() {\n\treturn 0;\n}");
        assert(root.valueBeforeCaret == "int main() {\n\t");

        const secondLineHome = root.caretIndex;
        root.draw();
        root.toggleHome();
        assert(root.caretIndex == secondLineHome - 1);

        root.toggleHome();
        assert(root.caretIndex == secondLineHome);

    }

    unittest {

        foreach (useTabs; [false, true]) {

            const tabLength = useTabs ? 1 : 4;

            auto io = new HeadlessBackend;
            auto root = codeInput();
            root.io = io;
            root.useTabs = useTabs;
            root.value = root.indentRope ~ "long line that wraps because the viewport is too small to make it fit";
            root.caretIndex = tabLength;
            root.draw();

            // Move to start
            root.toggleHome();
            assert(root.caretIndex == 0);

            // Move home
            root.toggleHome();
            assert(root.caretIndex == tabLength);

            // Move to line below
            root.runInputAction!(FluidInputAction.nextLine);

            // Move to line start
            root.caretToLineStart();
            assert(root.caretIndex > tabLength);

            const secondLineStart = root.caretIndex;

            // Move a few characters to the right, and move to line start again
            root.caretIndex = root.caretIndex + 5;
            root.toggleHome();
            assert(root.caretIndex == secondLineStart);

            // If the caret is already at the start, it should move home
            root.toggleHome();
            assert(root.caretIndex == tabLength);
            root.toggleHome();
            assert(root.caretIndex == 0);

        }

    }

    alias push = typeof(super).push;

    /// Insert text into the input. Reformat if necessary.
    ///
    /// This function handles pasting and typing input directly into the input. `push` is also used by `breakLine`,
    /// and thus, is called to insert line breaks into the input.
    ///
    /// `CodeInput` will automatically reformat the text while it is inserted. It will add line feeds to match the
    /// last line, or use the `indentor` to set the right indent.
    ///
    /// Params:
    ///     text    = Text to insert.
    ///     isMinor = True if this is a minor (insignificant) change.
    override void push(scope const(char)[] text, bool isMinor = true) {

        // Use minor status for these changes so they are merged together
        const isThisMinor = true;

        // If there's a selection, remove it
        replace(selectionLowIndex, selectionHighIndex, Rope.init, isThisMinor);
        clearSelection();

        const source = Rope(text);

        // Step 1: Find the common indent of all lines in the inserted text
        // This data will be needed for subsequent steps

        // Skip the first line because it's likely to be without indent when copy-pasting
        auto indentLines = source.byLine.drop(1);

        // Count indents on each line
        // Use the character count, assuming the indent is uniform
        auto allIndents = indentLines.save
            .map!(a => a
                .countUntil!(a => !a.among(' ', '\t')));

        // Ignore blank lines (no characters other than spaces)
        auto significantIndents = allIndents.save
            .filter!(a => a != -1);

        // Determine the common indent
        // It should be equivalent to the smallest indent of any blank line
        const commonIndent
            = !significantIndents.empty ? significantIndents.minElement()
            : !allIndents.empty         ? indentLines.map!"a.length".minElement()
            : 0;
        const originalIndentLevel = indentLevelByIndex(caretIndex);

        bool started;
        int indentLevel;
        foreach (line; source.byLine) {

            // Step 2: Remove the common indent
            // This way the indent in the inserted text will be uniform. It can then be replaced by indent
            // matching the text editor or indentor settings

            const localIndent = line
                .until!(a => !a.among(' ', '\t'))
                .walkLength;
            const removedIndent = min(commonIndent, localIndent);

            assert(line.isLeaf);
            assert(line.withSeparator.isLeaf);

            // Step 3: Apply the correct indent

            const lineStart = caretIndex;

            // Copy the original indent
            // Only add new indents after line breaks
            if (started) {
                insertTab(indentLevel);
            }

            // Write the line
            super.push(line.withSeparator.value[removedIndent .. $], isThisMinor);

            // Every line after the first should be indented relative to the first line. `indentLevel`
            // will be used as a reference. It is the lesser of indent level before and after the insert.
            // * The push may end up reducing the indent (based on caret position), so indent should be
            //   checked after the insert;
            // * Relative indent of each line in the clipboard should be preserved — an *increase* in indent should
            //   be ignored, so `originalIndentLevel` is still used as a reference.
            if (!started) {
                started = true;
                indentLevel = min(
                    originalIndentLevel,
                    indentLevelByIndex(lineStart));
            }

        }

        // Assign appropriate minor status for the action
        snapshot.isMinor = isMinor;

    }

    void rawPush(scope const(char)[] text, bool isMinor = true) {

        super.push(text, isMinor);

    }

    @("Text pasted into CodeInput is reformatted")
    unittest {

        import std.typecons;

        static abstract class Highlighter : CodeHighlighter {

            int highlightCount;

            override void parse(Rope, TextInterval, TextInterval, TextInterval) {
                highlightCount++;
            }

        }

        auto highlighter = new BlackHole!Highlighter;
        auto root = codeInput(highlighter);
        root.reparse();

        assert(highlighter.highlightCount == 1);

    }

    @("Legacy: CodeInput.paste creates a history entry (migrated)")
    unittest {

        auto io = new HeadlessBackend;
        auto root = codeInput(.useSpaces(2));
        root.io = io;

        io.clipboard = "World";
        root.savePush("  Hello,");
        root.runInputAction!(FluidInputAction.breakLine);
        root.runInputAction!(FluidInputAction.paste);
        assert(!root.snapshot.isMinor);
        root.savePush("!");
        assert(root.value == "  Hello,\n  World!");
        assert(root.valueBeforeCaret == root.value);

        // Undo the exclamation mark
        root.undo();
        assert(root.value == "  Hello,\n  World");
        assert(root.valueBeforeCaret == root.value);

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

    @("CodeInput: Undo and redo works")
    unittest {

        // Same test as above, but insert a space instead of line break

        auto io = new HeadlessBackend;
        auto root = codeInput(.useSpaces(2));
        root.io = io;

        io.clipboard = "World";
        root.savePush("  Hello,");
        assert( root.snapshot.isMinor);
        root.savePush(" ");
        assert( root.snapshot.isMinor);
        root.runInputAction!(FluidInputAction.paste);
        assert(!root.snapshot.isMinor);
        root.savePush("!");
        assert( root.snapshot.isMinor);
        assert(root.value == "  Hello, World!");

        // Undo the exclamation mark
        root.undo();
        assert(root.value == "  Hello, World");

        // Next undo moves before pasting, just like above
        root.undo();
        assert(root.value == "  Hello, ");
        assert(root.valueBeforeCaret == root.value);

        root.undo();
        assert(root.value == "");

        // No change
        root.undo();
        assert(root.value == "");

        root.redo();
        assert(root.value == "  Hello, ");
        assert(root.valueBeforeCaret == root.value);

    }

    unittest {

        auto io = new HeadlessBackend;
        auto root = codeInput(.useTabs);

        io.clipboard = "  foo\n  ";
        root.io = io;
        root.value = "let foo() {\n\t\n}";
        root.caretIndex = root.value.indexOf("\n}");
        root.paste();
        assert(root.value == "let foo() {\n\tfoo\n\t\n}");

        io.clipboard = "foo\n  bar\n";
        root.value = "let foo() {\n\tx\n}";
        root.caretIndex = root.value.indexOf("x");
        root.paste();
        assert(root.value == "let foo() {\n\tfoo\n\tbar\n\tx\n}");

    }

    override protected bool runLocalInputAction(immutable InputActionID id, bool active) {
        return runInputActionHandler(this, id, active);
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
    /// Params:
    ///     text    = New text to highlight.
    ///     start   = Index of the first character that has changed since last parse.
    ///         This begins both removed (start .. oldEnd) and inserted (start .. newEnd) fragments.
    ///     oldEnd  = Last index of the fragment that has been replaced.
    ///     newEnd  = Last index of newly inserted fragment.
    void parse(Rope text, TextInterval start, TextInterval oldEnd, TextInterval newEnd);

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

@("CodeInput invokes the syntax highlighter")
unittest {

    import std.typecons : BlackHole;

    enum tokenFunction = 1;
    enum tokenString = 2;

    auto text = `print("Hello, World!")`;
    auto highlighter = new class BlackHole!CodeHighlighter {

        override CodeSlice query(size_t byteIndex) {

            if (byteIndex == 0) return CodeSlice(0, 5, tokenFunction);
            if (byteIndex <= 6) return CodeSlice(6, 21, tokenString);
            return CodeSlice.init;

        }

    };

    auto root = codeInput(highlighter);
    root.value = text;
    root.draw();

    assert(root.contentLabel.text.styleMap.equal([
        TextStyleSlice(0, 5, tokenFunction),
        TextStyleSlice(6, 21, tokenString),
    ]));

}

unittest {

    auto roots = [
        codeInput(.nullTheme, .useSpaces(2)),
        codeInput(.nullTheme, .useTabs(2)),
    ];

    // Draw each root
    foreach (i, root; roots) {
        root.insertTab();
        root.push("a");
        root.draw();
    }

    assert(roots[0].value == "  a");
    assert(roots[1].value == "\ta");

    // Drawn text content has to be identical, since both have the same indent width
    assert(roots.all!(a => a.contentLabel.text.texture.chunks.length == 1));
    assert(roots[0].contentLabel.text.texture.chunks[0].image.data
        == roots[1].contentLabel.text.texture.chunks[0].image.data);

}

unittest {

    auto roots = [
        codeInput(.nullTheme, .useSpaces(1)),
        codeInput(.nullTheme, .useSpaces(2)),
        codeInput(.nullTheme, .useSpaces(4)),
        codeInput(.nullTheme, .useSpaces(8)),
        codeInput(.nullTheme, .useTabs(1)),
        codeInput(.nullTheme, .useTabs(2)),
        codeInput(.nullTheme, .useTabs(4)),
        codeInput(.nullTheme, .useTabs(8)),
    ];

    foreach (root; roots) {
        root.insertTab();
        root.push("a");
        root.draw();
    }

    assert(roots[0].value == " a");
    assert(roots[1].value == "  a");
    assert(roots[2].value == "    a");
    assert(roots[3].value == "        a");

    foreach (root; roots[4..8]) {

        assert(root.value == "\ta");

    }

    float indentWidth(CodeInput root) {
        return root.contentLabel.text.indentWidth;
    }

    foreach (i; [0, 4]) {

        assert(indentWidth(roots[i + 0]) * 2 == indentWidth(roots[i + 1]));
        assert(indentWidth(roots[i + 1]) * 2 == indentWidth(roots[i + 2]));
        assert(indentWidth(roots[i + 2]) * 2 == indentWidth(roots[i + 3]));

    }

    foreach (i; 0..4) {

        assert(indentWidth(roots[0 + i]) == indentWidth(roots[4 + i]),
            "Indent widths should be the same for both space and tab based roots");

    }

}

@("CodeInput formatting benchmark")
unittest {

    // This test may appear pretty stupid but it was used to diagnose a dumb bug
    // and a performance problem.
    // It should work in any case so it should stay anyway.

    import std.file;
    import std.datetime.stopwatch;
    import fluid.code_input;
    import fluid.backend.headless;

    const source = readText("source/fluid/text_input.d");

    auto io = new HeadlessBackend;
    auto root = codeInput();
    root.io = io;
    io.clipboard = source;

    root.draw();
    root.focus();

    root.paste();
    root.draw();

    const runCount = 1;
    const results = benchmark!({

        const target1 = root.value.length - root.value.byCharReverse.countUntil(";");
        const target = target1 - 1 - root.value[0..target1 - 1].byCharReverse.countUntil(";");

        root.caretIndex = target;
        root.paste();

    })(runCount);
    const average = results[0] / runCount;

    // Even if this is just a single paste, reformatting is bound to take a while.
    // I hope it could be faster in the future, but the current performance seems to be good enough;
    // I tried the same in IntelliJ and on my machine it's just about the same ~3 seconds,
    // Fluid might even be slightly faster.
    assert(average <= 5.seconds, format!"Too slow: average %s"(average));
    if (average > 1.seconds) {
        import std.stdio;
        writefln!"Warning: CodeInput formatting benchmark runs slowly, %s"(average);
    }

}

@("CodeInput.push correctly replaces selected text")
unittest {

    auto root = codeInput();
    root.value = `run(`
        ~ `    label("Hello, Fluid!")`
        ~ `);`;

    root.caretIndex = root.value.indexOf("!");
    root.draw();

    root.runInputAction!(FluidInputAction.selectPreviousWord);
    assert(root.selectedValue == "Fluid");
    root.savePush("W");

    assert(root.value == `run(`
        ~ `    label("Hello, W!")`
        ~ `);`);

}
