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
