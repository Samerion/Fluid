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

    override size_t nearestCharacter(Vector2 needle) {

        return contentLabel.text.indexAt(needle);

    }

    override TextRuler rulerAt(size_t index, bool preferNextLine = false) {

        return contentLabel.text.rulerAt(index, preferNextLine);

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
                placeholderText.draw(styles, inner.start);
            else
                text.draw(styles, inner.start);

        }

    }

    /// Get the full value of the text, including context provided via `prefix` and `suffix`.
    Rope sourceValue() const {

        // TODO This will allocate. Can it be avoided?
        return prefix ~ value ~ suffix;

    }

    /// Returns: A rope representing given indent level.
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

    ///
    unittest {

        auto root = codeInput(.useTabs);

        assert(root.indentRope == "\t");
        assert(root.indentRope(2) == "\t\t");
        assert(root.indentRope(3) == "\t\t\t");

    }

    unittest {

        auto root = codeInput();

        assert(root.indentRope == "    ");
        assert(root.indentRope(2) == "        ");
        assert(root.indentRope(3) == "            ");

    }

    protected override bool replaceNoHistory(size_t start, size_t end, Rope added, bool isMinor) {

        const replaced = super.replaceNoHistory(start, end, added, isMinor);
        reparse(start, end, added);

        return replaced;

    }

    protected void reparse() {

        // Act as if the whole document was replaced with itself
        reparse(0, value.length, value);

    }

    protected void reparse(size_t start, size_t end, Rope added) {

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

    override void resizeImpl(Vector2 vector) @trusted {

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

    unittest {

        auto root = codeInput();
        root.value = "a\n    b";
        root.draw();

        assert(root.lineHomeByIndex(0) == 0);
        assert(root.lineHomeByIndex(1) == 0);
        assert(root.lineHomeByIndex(2) == 6);
        assert(root.lineHomeByIndex(4) == 6);
        assert(root.lineHomeByIndex(6) == 6);
        assert(root.lineHomeByIndex(7) == 6);

    }

    unittest {

        auto root = codeInput();
        root.value = "a\n\tb";
        root.draw();

        assert(root.lineHomeByIndex(0) == 0);
        assert(root.lineHomeByIndex(1) == 0);
        assert(root.lineHomeByIndex(2) == 3);
        assert(root.lineHomeByIndex(3) == 3);
        assert(root.lineHomeByIndex(4) == 3);

        root.value = " \t b";
        foreach (i; 0 .. root.value.length) {

            assert(root.lineHomeByIndex(i) == 3);

        }

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
        else foreach (i; 0 .. indentLevel) {

            const spaces = "                ";

            static assert(spaces.length == maxIndentWidth);

            if (useTabs) {
                super.push('\t', isMinor);
            }

            // If inserting spaces make sure they're exactly aligned to the column
            else {
                const newSpace = indentWidth - (column!dchar % indentWidth);
                super.push(spaces[0 .. newSpace], isMinor);
            }

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

    unittest {

        auto root = codeInput(.useTabs);

        root.push("Hello, World!");
        root.caretToStart();
        root.insertTab();
        assert(root.value == "\tHello, World!");
        assert(root.valueBeforeCaret == "\t");

        root.undo();
        assert(root.value == "Hello, World!");
        assert(root.valueBeforeCaret == "");

        root.redo();
        assert(root.value == "\tHello, World!");
        assert(root.valueBeforeCaret == "\t");

        root.caretToEnd();
        root.outdent();
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
        const past = snapshot();

        // Indent every selected line
        foreach (start, line; eachSelectedLine) {

            // Skip empty lines
            if (!includeEmptyLines && line == "") continue;

            insertNoHistory(start, indentRope(indentCount), isMinor);

        }

        pushHistory(past);

    }

    unittest {

        auto root = codeInput();
        root.value = "a";
        root.indent();
        assert(root.value == "    a");

        root.value = "abc\ndef\nghi\njkl";
        root.selectSlice(4, 9);
        root.indent();
        assert(root.value == "abc\n    def\n    ghi\njkl");

        root.indent(2);
        assert(root.value == "abc\n            def\n            ghi\njkl");

    }

    unittest {

        auto root = codeInput(.useSpaces(3));
        root.value = "a";
        root.indent();
        assert(root.value == "   a");

        root.value = "abc\ndef\nghi\njkl";
        assert(root.lineByIndex(4) == "def");
        root.selectSlice(4, 9);
        root.indent();

        assert(root.value == "abc\n   def\n   ghi\njkl");

        root.indent(2);
        assert(root.value == "abc\n         def\n         ghi\njkl");

    }

    unittest {

        auto root = codeInput(.useTabs);
        root.value = "a";
        root.indent();
        assert(root.value == "\ta");

        root.value = "abc\ndef\nghi\njkl";
        root.selectSlice(4, 9);
        root.indent();
        assert(root.value == "abc\n\tdef\n\tghi\njkl");

        root.indent(2);
        assert(root.value == "abc\n\t\t\tdef\n\t\t\tghi\njkl");

    }

    @(FluidInputAction.outdent)
    void outdent() {

        outdent(1);

    }
    
    void outdent(int level) {

        const isMinor = true;
        const past = snapshot();

        // Outdent every selected line
        foreach (start, line; eachSelectedLine) {

            // Do it for each indent
            foreach (j; 0 .. level) {

                const leadingWidth = line.take(indentWidth)
                    .until!(a => !a.among(' ', '\t'))
                    .until("\t", No.openRight)
                    .walkLength;

                replaceNoHistory(start, start + leadingWidth, Rope.init, isMinor);

            }

        }

        pushHistory(past);

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

                    const oldCaretIndex = caretIndex;
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

    unittest {

        auto root = codeInput(.useSpaces(2));
        root.value = "      abc";
        root.caretIndex = 6;
        root.chop();
        assert(root.value == "    abc");
        root.chop();
        assert(root.value == "  abc");
        root.chop();
        assert(root.value == "abc");
        root.chop();
        assert(root.value == "abc");

        root.undo();
        assert(root.value == "      abc");
        assert(root.valueAfterCaret == "abc");


    }

    @("CodeInput.breakLine continues the indent")
    unittest {

        auto root = codeInput();

        root.push("abcdef");
        root.runInputAction!(FluidInputAction.breakLine);
        assert(root.value == "abcdef\n");

        root.insertTab();
        root.runInputAction!(FluidInputAction.breakLine);
        assert(root.value == "abcdef\n    \n    ");

        root.insertTab();
        root.runInputAction!(FluidInputAction.breakLine);
        assert(root.value == "abcdef\n    \n        \n        ");

        root.outdent();
        root.outdent();
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
        const newLineLength = newIndent.length + line.length - oldIndentLength;
        const isMinor = true;

        // Write the new indent, replacing the old one
        replaceNoHistory(lineStart, lineStart + oldIndentLength, newIndent, isMinor);

        // Update caret index
        if (oldCaretIndex >= lineStart && oldCaretIndex <= lineEnd)
            setCaretIndexNoHistory(
                clamp(oldCaretIndex + newIndent.length - oldIndentLength,
                    lineStart + newIndent.length,
                    lineStart + newLineLength));

    }

    /// Reformat the current line.
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

        // If there's a selection, remove it
        replace(selectionLowIndex, selectionHighIndex, Rope.init, isMinor);
        caretIndex = selectionLowIndex;

        const source = Rope(text);

        // Step 1: Find the common indent of all lines in the inserted text
        // This data will be needed for subsequent steps
        
        // Skip the first line because it's likely to be without indent when copy-pasting
        auto indentLines = source.byLine.drop(1);

        // Count indents on each line
        auto significantIndents = indentLines.save 

            // Use the character count, assuming the indent is uniform
            .map!(a => a
                .countUntil!(a => !a.among(' ', '\t')))

            // Ignore blank lines (no characters other than spaces)
            .filter!(a => a != -1);

        // Determine the common indent
        // It should be equivalent to the smallest indent of any blank line
        const commonIndent = !significantIndents.empty ? significantIndents.minElement() : 0;
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

            // Use minor status for these changes so they are merged together
            const isThisMinor = true;
            const lineStart = caretIndex;

            // Copy the original indent
            // Only add new indents after line breaks
            if (started && !indentor) {
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

            // Use the reformatter if available
            // TODO wouldn't it be better to reformat the fragment in a separate pass?
            else if (indentor) {
                reformatLineByIndex(lineStart);
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

        auto io = new HeadlessBackend;
        auto root = codeInput(.useTabs);

        io.clipboard = "text";
        root.io = io;
        root.insertTab;
        root.paste();
        assert(root.value == "\ttext");

        root.breakLine;
        root.paste();
        assert(root.value == "\ttext\n\ttext");

        io.clipboard = "text\ntext";
        root.value = "";
        root.paste();
        assert(root.value == "text\ntext");

        root.breakLine;
        root.insertTab;
        root.paste();
        assert(root.value == "text\ntext\n\ttext\n\ttext");

        io.clipboard = "  {\n    text\n  }\n";
        root.value = "";
        root.paste();
        assert(root.value == "{\n  text\n}\n");

        root.value = "\t";
        root.caretToEnd();
        root.paste();
        assert(root.value == "\t{\n\t  text\n\t}\n\t");

        root.value = "\t";
        root.caretToStart();
        root.paste();
        assert(root.value == "{\n  text\n}\n\t");

    }

    unittest {

        auto io = new HeadlessBackend;
        auto root = codeInput();
        root.io = io;

        foreach (i, clipboard; ["", "  ", "    ", "\t", "\t\t"]) {

            io.clipboard = clipboard;
            root.value = "";
            root.paste();
            assert(root.value == clipboard,
                format!"Clipboard preset index %s (%s) not preserved"(i, clipboard));

        }

    }

    unittest {

        auto io = new HeadlessBackend;
        auto root = codeInput(.useTabs);

        io.clipboard = "text\ntext";
        root.io = io;
        root.value = "let foo() {\n\tbar\t\tbaz\n}";
        root.selectSlice(
            root.value.indexOf("bar"),
            root.value.indexOf("baz"),
        );
        root.paste();
        assert(root.value == "let foo() {\n\ttext\n\ttextbaz\n}");

        io.clipboard = "\t\ttext\n\ttext";
        root.value = "let foo() {\n\tbar\t\tbaz\n}";
        root.selectSlice(
            root.value.indexOf("bar"),
            root.value.indexOf("baz"),
        );
        root.paste();
        assert(root.value == "let foo() {\n\t\ttext\n\ttextbaz\n}");

    }

    unittest {

        auto io = new HeadlessBackend;
        auto root = codeInput(.useSpaces(2));
        root.io = io;

        io.clipboard = "World";
        root.push("  Hello,");
        root.runInputAction!(FluidInputAction.breakLine);
        root.paste();
        assert(!root.snapshot.isMinor);
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

    unittest {

        // Same test as above, but insert a space instead of line break

        auto io = new HeadlessBackend;
        auto root = codeInput(.useSpaces(2));
        root.io = io;

        io.clipboard = "World";
        root.push("  Hello,");
        root.push(" ");
        root.paste();
        root.push("!");
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

        auto indentor = new class CodeIndentor {

            Rope text;

            void parse(Rope text) {

                this.text = text;

            }

            int indentDifference(ptrdiff_t offset) {

                int lastLine;
                int current;
                int nextLine;

                foreach (ch; text[0 .. offset+1].byDchar) {

                    if (ch == '{')
                        nextLine++;
                    else if (ch == '}')
                        current--;
                    else if (ch == '\n') {
                        lastLine = current;
                        current = nextLine;
                    }

                }

                return current - lastLine;

            }

        };
        auto io = new HeadlessBackend;
        auto root = codeInput(.useTabs);

        // In this test, the indentor does nothing but preserve last indent
        io.clipboard = "text\ntext";
        root.io = io;
        root.indentor = indentor;
        root.insertTab;
        root.paste();
        assert(root.value == "\ttext\n\ttext");

        io.clipboard = "let foo() {\n\tbar\n}";
        root.value = "";
        root.paste();
        assert(root.value == "let foo() {\n\tbar\n}");

        root.caretIndex = root.value.indexOf("bar");
        root.runInputAction!(FluidInputAction.selectNextWord);
        assert(root.selectedValue == "bar");

        root.paste();
        assert(root.value == "let foo() {\n\tlet foo() {\n\t\tbar\n\t}\n}");

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

interface CodeIndentor {

    /// Parse the given text.
    void parse(Rope text);

    /// Get indent level for the given offset, relative to the previous line.
    ///
    /// `CodeInput` will use the first non-white character on a line as a reference for reformatting.
    int indentDifference(ptrdiff_t offset);

}

unittest {

    import std.typecons : BlackHole;

    auto originalText
       = "void foo() {\n"
       ~ "fun();\n"
       ~ "functionCall(\n"
       ~ "stuff()\n"
       ~ ");\n"
       ~ "    }\n";
    auto formattedText
       = "void foo() {\n"
       ~ "    fun();\n"
       ~ "    functionCall(\n"
       ~ "        stuff()\n"
       ~ "    );\n"
       ~ "}\n";

    class Indentor : BlackHole!CodeIndentor {

        struct Indent {
            ptrdiff_t offset;
            int indent;
        }

        Indent[] indents;

        override void parse(Rope rope) {

            bool lineStart;

            indents = [Indent(0, 0)];

            foreach (i, ch; rope.enumerate) {

                if (ch.among('{', '(')) {
                    indents ~= Indent(i + 1, 1);
                }

                else if (ch.among('}', ')')) {
                    indents ~= Indent(i, lineStart ? -1 : 0);
                }

                else if (ch == '\n') lineStart = true;
                else if (ch != ' ') lineStart = false;

            }

        }

        override int indentDifference(ptrdiff_t offset) {

            return indents
                .filter!(a => a.offset <= offset)
                .tail(1)
                .front
                .indent;

        }

    }

    auto indentor = new Indentor;
    auto highlighter = new class Indentor, CodeHighlighter {

        const(char)[] nextTokenName(ubyte) {
            return null;
        }

        CodeSlice query(size_t) {
            return CodeSlice.init;
        }

        override void parse(Rope value) {
            super.parse(value);
        }

    };

    auto indentorOnlyInput = codeInput();
    indentorOnlyInput.indentor = indentor;
    auto highlighterInput = codeInput(highlighter);

    foreach (root; [indentorOnlyInput, highlighterInput]) {

        root.value = originalText;
        root.draw();

        // Reformat first line
        root.caretIndex = 0;
        assert(root.targetIndentLevelByIndex(0) == 0);
        root.reformatLine();
        assert(root.value == originalText);

        // Reformat second line
        root.caretIndex = 13;
        assert(root.indentor.indentDifference(13) == 1);
        assert(root.targetIndentLevelByIndex(13) == 1);
        root.reformatLine();
        assert(root.value == formattedText[0..23] ~ originalText[19..$]);

        // Reformat third line
        root.caretIndex = 24;
        assert(root.indentor.indentDifference(24) == 0);
        assert(root.targetIndentLevelByIndex(24) == 1);
        root.reformatLine();
        assert(root.value == formattedText[0..42] ~ originalText[34..$]);

        // Reformat fourth line
        root.caretIndex = 42;
        assert(root.indentor.indentDifference(42) == 1);
        assert(root.targetIndentLevelByIndex(42) == 2);
        root.reformatLine();
        assert(root.value == formattedText[0..58] ~ originalText[42..$]);

        // Reformat fifth line
        root.caretIndex = 58;
        assert(root.indentor.indentDifference(58) == -1);
        assert(root.targetIndentLevelByIndex(58) == 1);
        root.reformatLine();
        assert(root.value == formattedText[0..65] ~ originalText[45..$]);

        // And the last line, finally
        root.caretIndex = 65;
        assert(root.indentor.indentDifference(65) == -1);
        assert(root.targetIndentLevelByIndex(65) == 0);
        root.reformatLine();
        assert(root.value == formattedText);

    }

}

@("CodeInput can use a formatter for indenting")
unittest {

    import std.typecons : BlackHole;

    class Indentor : BlackHole!CodeIndentor {

        bool outdent;

        override void parse(Rope rope) {

            outdent = rope.canFind("end");

        }

        override int indentDifference(ptrdiff_t offset) {

            if (outdent)
                return -1;
            else
                return 1;

        }

    }

    // Every new line indents. If "end" is found in the text, every new line *outdents*, effectively making the text
    // flat.
    auto io = new HeadlessBackend;
    auto root = codeInput();
    root.io = io;
    root.indentor = new Indentor;
    root.value = "begin";
    root.focus();
    root.draw();
    assert(root.value == "begin");

    // The difference defaults to 1 in this case, so the line should be indented
    root.reformatLine();
    assert(root.value == "    begin");

    // But, if the "end" keyword is added, it should outdent automatically
    io.nextFrame;
    io.inputCharacter = " end";
    root.caretToEnd();
    root.draw();
    io.nextFrame;
    root.draw();
    assert(root.value == "begin end");

    // Backspace also triggers updates
    io.nextFrame;
    io.press(KeyboardKey.backspace);
    root.draw();
    io.nextFrame;
    io.release(KeyboardKey.backspace);
    root.draw();
    assert(root.value == "    begin en");

    // However, no change should be made if the keyword was in place before
    io.nextFrame;
    io.inputCharacter = " ";
    root.value = "    begin end";
    root.caretToEnd();
    root.draw();
    io.nextFrame;
    root.draw();
    assert(root.value == "    begin end ");

    io.nextFrame;
    root.value = "Hello\n    bar";
    root.clearHistory();
    root.caretIndex = 5;
    root.runInputAction!(FluidInputAction.breakLine);
    assert(root.value == "Hello\n    \n    bar");

    root.runInputAction!(FluidInputAction.undo);
    assert(root.value == "Hello\n    bar");

    root.indent();
    assert(root.value == "    Hello\n    bar");

    root.caretIndex = 9;
    root.runInputAction!(FluidInputAction.breakLine);
    assert(root.value == "    Hello\n        \n    bar");

    root.runInputAction!(FluidInputAction.undo);
    assert(root.value == "    Hello\n    bar");

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
