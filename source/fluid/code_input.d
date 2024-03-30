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

        /// Character width of a single indent level.
        int indentWidth = 4;
        invariant(indentWidth <= maxIndentWidth);

        /// If true, uses the tab character for indents. Not supported at the moment.
        enum bool isTabIndent = false;

    }

    public {

        /// Current token type, used for styling individual token types and **only relevant in themes**.
        const(char)[] token;

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
        Text!(ContentLabel, CodeHighlighter.Range) text;
        Style[256] styles;

        this() {

            text = typeof(text)(this, "", CodeHighlighter.Range.init);
            text.hasFastEdits = true;

        }

        override void resizeImpl(Vector2 available) {

            assert(text.hasFastEdits);

            this.text.value = super.text.value;
            text.resize(available);
            minSize = text.size;

        }

        override void drawImpl(Rectangle outer, Rectangle inner) {

            const style = pickStyle();
            text.draw(styles, inner.start);

        }

    }

    protected void reparse() {

        // Parse the file
        if (highlighter) {

            highlighter.parse(value);

            // Apply highlighting to the label
            contentLabel.text.styleMap = highlighter.save;

        }

        // Pass the file to the indentor
        if (indentor && cast(Object) indentor !is cast(Object) highlighter) {

            indentor.parse(value);

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

        // Parse changes
        reparse();

        // Resize the field
        super.resizeImpl(vector);

        // Reload token styles
        if (highlighter) {

            CodeToken tokenIndex;
            while (++tokenIndex) {

                token = highlighter.nextTokenName(tokenIndex);

                if (token is null) break;

                contentLabel.styles[tokenIndex] = pickStyle();

            }

        }

    }

    // TODO move as many of these to Rope or TextInput...

    /// Get line by a byte index.
    Rope lineByIndex(KeepTerminator keepTerminator = No.keepTerminator)(ptrdiff_t index) const {

        import std.utf;
        import fluid.typeface;

        index = index.clamp(0, value.length);

        const backLength = Typeface.lineSplitter(value[0..index].retro).front.byChar.walkLength;
        const frontLength = Typeface.lineSplitter!keepTerminator(value[index..$]).front.byChar.walkLength;

        // Combine everything on the same line, before and after the cursor
        return value[index - backLength .. index + frontLength];

    }

    unittest {

        auto root = codeInput();
        assert(root.lineByIndex(0) == "");
        assert(root.lineByIndex(1) == "");

        root.push("aaą\nbbČb\n c \r\n\n **Ą\n");
        assert(root.lineByIndex(0) == "aaą");
        assert(root.lineByIndex(1) == "aaą");
        assert(root.lineByIndex(4) == "aaą");
        assert(root.lineByIndex(5) == "bbČb");
        assert(root.lineByIndex(7) == "bbČb");
        assert(root.lineByIndex(10) == "bbČb");
        assert(root.lineByIndex(11) == " c ");
        assert(root.lineByIndex!(Yes.keepTerminator)(11) == " c \r\n");
        assert(root.lineByIndex(16) == "");
        assert(root.lineByIndex!(Yes.keepTerminator)(16) == "\n");
        assert(root.lineByIndex(17) == " **Ą");
        assert(root.lineByIndex(root.value.length) == "");
        assert(root.lineByIndex!(Yes.keepTerminator)(root.value.length) == "");

    }

    /// Update a line with given byte index.
    const(char)[] lineByIndex(ptrdiff_t index, const(char)[] value) {

        lineByIndex(index, Rope(value));
        return value;

    }

    /// ditto
    Rope lineByIndex(ptrdiff_t index, Rope newValue) {

        import std.utf;
        import fluid.typeface;

        index = index.clamp(0, value.length);

        const backLength = Typeface.lineSplitter(value[0..index].retro).front.byChar.walkLength;
        const frontLength = Typeface.lineSplitter(value[index..$]).front.byChar.walkLength;
        const start = index - backLength;
        const end = index + frontLength;
        ptrdiff_t[2] selection = [selectionStart, selectionEnd];

        // Combine everything on the same line, before and after the cursor
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

        auto root = codeInput();
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

        auto root = codeInput();
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

    /// Get the current line
    Rope caretLine() {

        return lineByIndex(caretIndex);

    }

    unittest {

        auto root = codeInput();
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

        auto root = codeInput();
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

    /// Get the column the given index is on. Uses characters rather than bytes.
    ptrdiff_t column(chartype)(size_t index) const {

        import std.utf;
        import fluid.typeface;

        // Get last line
        return Typeface.lineSplitter(value[0..index].retro).front

            // Count characters
            .byUTF!chartype.walkLength;

    }

    /// Get the column the cursor is on. Uses characters rather than bytes.
    ptrdiff_t column(chartype)() {

        return column!chartype(caretIndex);

    }

    unittest {

        auto root = codeInput();
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

            CodeInput input;
            ptrdiff_t index;
            ptrdiff_t end;

            private Rope front;
            private ptrdiff_t nextLine;

            alias SetLine = void delegate(Rope line) @safe;

            int opApply(scope int delegate(Rope line, scope SetLine setLine) @safe yield) {

                while (index <= end) {

                    const line = input.lineByIndex!(Yes.keepTerminator)(index);
                    front = line[].chomp;

                    // Get index of the next line
                    nextLine = index + line.length - input.column!char(index);

                    // Output the line
                    if (auto stop = yield(front, &setLine)) return stop;

                    // Stop if reached the end of string
                    if (index == nextLine) return 0;

                    // Move to the next line
                    index = nextLine;

                }

                return 0;

            }

            int opApply(scope int delegate(Rope line) @safe yield) {

                foreach (line, setLine; this) {

                    if (auto stop = yield(line)) return stop;

                }

                return 0;

            }

            /// Replace the current line with a new one.
            void setLine(Rope line) @safe {

                const lineStart = index - input.column!char(index);

                // Get the size of the line terminator
                const lineTerminatorLength = nextLine - lineStart - front.length;

                // Update the line
                input.lineByIndex(index, line);
                index = lineStart + line.length;
                end += line.length - front.length;

                // Add the terminator
                nextLine = index + lineTerminatorLength;

            }

        }

        return LineIterator(this, start, end);

    }

    unittest {

        auto root = codeInput();
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

        auto root = codeInput();
        root.push("skip\nonë\r\ntwo\r\nthree\n");

        assert(root.lineByIndex(4) == "skip");
        assert(root.lineByIndex(8) == "onë");
        assert(root.lineByIndex(12) == "two");

        size_t i;
        foreach (line, setLine; root.eachLineByIndex(5, root.value.length)) {

            if (i == 0) {
                setLine(Rope("value"));
                assert(line == "onë");
                assert(root.value == "skip\nvalue\r\ntwo\r\nthree\n");
            }
            else if (i == 1) {
                setLine(Rope("\nbar-bar-bar-bar-bar"));
                assert(line == "two");
                assert(root.value == "skip\nvalue\r\n\nbar-bar-bar-bar-bar\r\nthree\n");
            }
            else if (i == 2) {
                setLine(Rope.init);
                assert(line == "three");
                assert(root.value == "skip\nvalue\r\n\nbar-bar-bar-bar-bar\r\n\n");
            }
            else if (i == 3) {
                assert(line == "");
            }
            else assert(false);

            i++;

        }

        assert(i == 4);

    }

    unittest {

        auto root = codeInput();
        root.push("Fïrst line\nSëcond line\r\n Third line\n    Fourth line\rFifth line");

        size_t i = 0;
        foreach (line, setLine; root.eachLineByIndex(19, 49)) {

            setLine("    " ~ line);

            if (i == 0) assert(line == "Sëcond line");
            else if (i == 1) assert(line == " Third line");
            else if (i == 2) assert(line == "    Fourth line");
            else assert(false);
            i++;

        }
        assert(i == 3);
        root.selectionStart = 19;
        root.selectionEnd = 49;

    }

    /// Get indent count for offset at given index.
    ptrdiff_t indentLevelByIndex(size_t i) {

        // Select tabs on the given line
        return lineByIndex(i)
            .until!(a => a != ' ')

            // Count their width
            .walkLength / indentWidth;

    }

    ptrdiff_t targetIndentLevelByIndex(size_t i) {

        const line = lineByIndex(i);
        const col = column!char;
        const lineStart = i - col;

        // Use the indentor if available
        if (indentor) {

            const lineEnd = lineStart + line.length;
            const indentEnd = lineStart + line[].until!(a => a != ' ').walkLength;

            return max(0, indentor.indentLevel(indentEnd));

        }

        // Perform basic autoindenting if indentor is not available
        else {

            const untilPreviousLine = value[0..lineStart].chomp;

            // Select tabs on the given line
            return indentLevelByIndex(untilPreviousLine.length);

        }

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

    /// Return each line containing the selection.
    auto eachSelectedLine() {

        return eachLineByIndex(selectionLowIndex, selectionHighIndex);

    }

    @(FluidInputAction.insertTab)
    void insertTab() {

        // Indent selection
        if (isSelecting) indent();

        // Align to tab
        else {

            char[maxIndentWidth] insertTab = ' ';

            const newSpace = indentWidth - (column!dchar % indentWidth);

            push(insertTab[0 .. newSpace]);

        }

    }

    unittest {

        auto root = codeInput();
        root.insertTab();
        assert(root.value == "    ");
        root.push("aa");
        root.insertTab();
        assert(root.value == "    aa  ");
        root.insertTab();
        assert(root.value == "    aa      ");
        root.push("\n");
        root.insertTab();
        assert(root.value == "    aa      \n    ");
        root.insertTab();
        assert(root.value == "    aa      \n        ");
        root.push("||");
        root.insertTab();
        assert(root.value == "    aa      \n        ||  ");

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

    @(FluidInputAction.indent)
    void indent() {

        char[maxIndentWidth] insertTab = ' ';
        const indent = Rope(insertTab[0 .. indentWidth].dup);

        // Indent every selected line
        foreach (line, setLine; eachSelectedLine) {

            // Skip empty lines
            if (line == "") continue;

            setLine(indent[] ~ line);

        }

    }

    @(FluidInputAction.outdent)
    void outdent() {

        // Outdent every selected line
        foreach (line, setLine; eachSelectedLine) {

            const leadingWidth = line.take(indentWidth)
                .until!(a => a != ' ')
                .walkLength;

            // Remove the tab
            setLine(line[leadingWidth .. $]);

        }

    }

    unittest {

        auto root = codeInput();
        root.outdent();
        assert(root.value == "");

        root.push("  ");
        root.outdent();
        assert(root.value == "");

        root.push("    ");
        root.outdent();
        assert(root.value == "");

        root.push("     ");
        root.outdent();
        assert(root.value == " ");

        root.push("foobarbaz  ");
        root.insertTab();
        root.outdent();
        assert(root.value == "foobarbaz      ");

        root.outdent();
        assert(root.value == "foobarbaz      ");

        root.push("\n   abc  ");
        root.outdent();
        assert(root.value == "foobarbaz      \nabc  ");

    }

    override void chop(bool forward = false) {

        // Make it possible to backspace tabs
        if (!forward && !isSelecting) {

            const col = column!char;
            const line = caretLine;
            const isIndent = line[0 .. col].all!(a => a == ' ');
            const oldCaretIndex = caretIndex;

            // Remove spaces as if they were tabs
            if (isIndent && col) {

                const tabWidth = either(column!dchar % indentWidth, indentWidth);

                caretLine = line[tabWidth .. $];
                caretIndex = oldCaretIndex - tabWidth;

                return;

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

    @(FluidInputAction.breakLine)
    protected override bool onBreakLine() {

        char[maxIndentWidth] insertTab = ' ';

        // Break the line
        if (super.onBreakLine()) {

            reparse();
            reformatLine();

            return true;

        }

        return false;

    }

    /// CodeInput implements autoindenting.
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

    }

    /// Reformat the current line.
    void reformatLine() {

        import std.math;

        char[maxIndentWidth] insertTab = ' ';

        // TODO
        if (isSelecting) return;

        const col = column!char(caretIndex);
        const index = caretIndex;
        const currentIndent = indentLevelByIndex(index);
        const newIndent = targetIndentLevelByIndex(index);

        // Ignore if indent is the same
        if (newIndent == currentIndent) return;

        const diff = newIndent - currentIndent;
        const oldCaretIndex = caretIndex;

        // Indent reduced
        if (newIndent < currentIndent)
            caretLine = caretLine[-diff * indentWidth .. $];

        // Indent increased
        else foreach (i; 0 .. diff)
            caretLine = insertTab[0 .. indentWidth].dup ~ caretLine;

        caretIndex = oldCaretIndex + diff*indentWidth;

        // Parse again
        reparse();

    }

}

alias CodeToken = ubyte;

struct CodeRange {

    auto start = size_t.max;
    auto end = size_t.max;
    CodeToken token;

    alias toTextStyleSlice this;

    TextStyleSlice toTextStyleSlice() const {

        return TextStyleSlice(start, end, token);

    }

}

interface CodeHighlighter {

    alias Range = typeof(CodeHighlighter.save());

    /// Get a name for the token at given index. Returns null if there isn't a token at given index. Indices must be
    /// sequential. Starts at 1.
    const(char)[] nextTokenName(CodeToken index);

    /// Parse the given text.
    void parse(Rope text);

    /// Find the next important range starting with the byte at given index.
    ///
    /// Tip: Query is likely to be called again with `byteIndex` set to the value of `range.end`.
    ///
    /// Returns:
    ///     The next relevant code range. Parts with no highlighting should be ignored. If there is nothing left to
    ///     highlight, should return `init`.
    CodeRange query(size_t byteIndex);

    /// Produce a TextStyleSlice range using the result.
    final save() {

        struct HighlighterRange {

            CodeHighlighter highlighter;
            TextStyleSlice front;

            bool empty() const {

                return front is front.init;

            }

            // Continue where the last token ended
            void popFront() {

                do front = highlighter.query(front.end).toTextStyleSlice;

                // Pop again if got a null token
                while (front.styleIndex == 0 && front !is front.init);

            }

            HighlighterRange save() {

                return this;

            }

        }

        return HighlighterRange(this, query(0).toTextStyleSlice);

    }

}

interface CodeIndentor {

    /// Parse the given text.
    void parse(Rope text);

    /// Get absolute indent level at given offset.
    int indentLevel(ptrdiff_t offset);

    /// Get indent level for the given offset, relative to the previous line.
    int indentDifference(ptrdiff_t offset);

}
