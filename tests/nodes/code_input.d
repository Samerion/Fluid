module nodes.code_input;

import fluid;

import std.range;
import std.string;
import std.algorithm;

@safe:

@("CodeInput.lineHomeByIndex returns first non-blank character of the line")
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

@("CodeInput.lineHomeByIndex recognizes tabs")
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

@("CodeInput.visualColumns counts tabs as indents")
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

@("CodeInput.indentLevelByIndex returns indent level for the line (spaces)")
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

@("CodeInput.indentLevelByIndex returns indent level for the line (mixed tabs & spaces)")
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

@("CodeInput.insertTab inserts spaces according to current column")
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

@("CodeInput.insertTab inserts spaces according to current column (2 spaces)")
unittest {

    auto root = codeInput(.useSpaces(2));
    root.insertTab();
    assert(root.value == "  ");
    root.push("aa");
    root.insertTab();
    assert(root.value == "  aa  ");
    root.insertTab();
    assert(root.value == "  aa    ");
    root.push("\n");
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

@("CodeInput.insertTab inserts tabs")
unittest {

    auto root = codeInput(.useTabs);
    root.insertTab();
    assert(root.value == "\t");
    root.push("aa");
    root.insertTab();
    assert(root.value == "\taa\t");
    root.insertTab();
    assert(root.value == "\taa\t\t");
    root.push("\n");
    root.insertTab();
    assert(root.value == "\taa\t\t\n\t");
    root.insertTab();
    assert(root.value == "\taa\t\t\n\t\t");
    root.push("||");
    root.insertTab();
    assert(root.value == "\taa\t\t\n\t\t||\t");

}

@("CodeInput.insertTab indents if text is selected")
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

@("CodeInput.insertTab/outdent respect edit history")
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

@("CodeInput.indent can insert multiple tabs in selection")
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

@("CodeInput.indent works well with useSpaces(3)")
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

@("CodeInput.indent works well with tabs")
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

@("CodeInput.outdent() removes indents for spaces and tabs")
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
    root.outdent();
    assert(root.value == " ");

    root.push("foobarbaz  ");
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

@("Tab inside of CodeInput can indent and outdent")
unittest {

    auto map = InputMapping();
    map.bindNew!(FluidInputAction.insertTab)(KeyboardIO.codes.tab);
    map.bindNew!(FluidInputAction.outdent)(KeyboardIO.codes.leftShift, KeyboardIO.codes.tab);

    auto input = codeInput();
    auto focus = focusChain(input);
    auto root = inputMapChain(map, focus);
    focus.currentFocus = input;
    root.draw();

    // Tab twice
    foreach (i; 0..2) {

        assert(input.value.length == i*4);

        focus.emitEvent(KeyboardIO.press.tab);
        root.draw();

    }

    assert(input.value == "        ");
    assert(input.valueBeforeCaret == "        ");

    // Outdent
    focus.emitEvent(KeyboardIO.press.leftShift);
    focus.emitEvent(KeyboardIO.press.tab);
    root.draw();

    assert(input.value == "    ");
    assert(input.valueBeforeCaret == "    ");

}

@("CodeInput.outdent will remove tabs in .useSpaces(2)")
unittest {

    auto root = codeInput(.useSpaces(2));
    root.value = "    abc";
    root.outdent();
    assert(root.value == "  abc");
    root.outdent();
    assert(root.value == "abc");

}

@("CodeInput.chop removes treats indents as characters")
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

@("CodeInput.chop works with mixed indents")
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

@("CodeInput.chop works with indent of 2 spaces")
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

@("breakLine preserves tabs from last line in CodeInput")
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

@("CodeInput.breakLine keeps tabs from last line in .useSpaces(2)")
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

@("CodeInput.breakLine keeps tabs from last line if inserted in the middle of the line")
unittest {

    auto root = codeInput();
    root.value = "    abcdef";
    root.caretIndex = 8;
    root.breakLine;
    assert(root.value == "    abcd\n    ef");

}

@("CodeInput.reformatLine converts indents to the correct indent character")
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

@("CodeInput.toggleHome moves to a line's home, or start if already at home")
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

@("CodeInput.toggleHome works with both tabs and spaces")
unittest {

    foreach (useTabs; [false, true]) {

        const tabLength = useTabs ? 1 : 4;

        auto root = codeInput();
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

@("CodeInput supports syntax hgihlighting with CodeHighlighter")
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
    root.draw();

    assert(root.contentLabel.text.styleMap.equal([
        TextStyleSlice(0, 5, tokenFunction),
        TextStyleSlice(6, 21, tokenString),
    ]));

}

@("CodeInput can use CodeIndentor separate from CodeHighlighter")
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

@("Spaces and tabs are equivalent in width if configured so in CodeInput")
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

@("Indent width in CodeInput affects space characters but not tabs")
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

@("CodeInput.paste changes indents to match the current text")
unittest {

    auto input = codeInput(.useTabs);
    auto clipboard = clipboardChain(input);
    auto root = clipboard;
    root.draw();

    clipboard.value = "text";
    input.insertTab;
    input.paste();
    assert(input.value == "\ttext");

    input.breakLine;
    input.paste();
    assert(input.value == "\ttext\n\ttext");

    clipboard.value = "text\ntext";
    input.value = "";
    input.paste();
    assert(input.value == "text\ntext");

    input.breakLine;
    input.insertTab;
    input.paste();
    assert(input.value == "text\ntext\n\ttext\n\ttext");

    clipboard.value = "  {\n    text\n  }\n";
    input.value = "";
    input.paste();
    assert(input.value == "{\n  text\n}\n");

    input.value = "\t";
    input.caretToEnd();
    input.paste();
    assert(input.value == "\t{\n\t  text\n\t}\n\t");

    input.value = "\t";
    input.caretToStart();
    input.paste();
    assert(input.value == "{\n  text\n}\n\t");

}

@("CodeInput.paste keeps the pasted value as-is if it's composed of spaces or tabs")
unittest {

    auto input = codeInput();
    auto clipboard = clipboardChain();
    auto root = chain(clipboard, input);
    root.draw();

    foreach (i, value; ["", "  ", "    ", "\t", "\t\t"]) {

        clipboard.value = value;
        input.value = "";
        input.paste();
        assert(input.value == value,
            format!"Clipboard preset index %s (%s) not preserved"(i, value));

    }

}

@("CodeInput.paste replaces the selection")
unittest {

    auto input = codeInput(.useTabs);
    auto clipboard = clipboardChain();
    auto root = chain(clipboard, input);
    root.draw();

    clipboard.value = "text\ntext";
    input.value = "let foo() {\n\tbar\t\tbaz\n}";
    input.selectSlice(
        input.value.indexOf("bar"),
        input.value.indexOf("baz"),
    );
    input.paste();
    assert(input.value == "let foo() {\n\ttext\n\ttextbaz\n}");

    clipboard.value = "\t\ttext\n\ttext";
    input.value = "let foo() {\n\tbar\t\tbaz\n}";
    input.selectSlice(
        input.value.indexOf("bar"),
        input.value.indexOf("baz"),
    );
    input.paste();
    assert(input.value == "let foo() {\n\t\ttext\n\ttextbaz\n}");

}

@("CodeInput.paste creates a history entry (single line)")
unittest {

    // Same test as above, but insert a space instead of line break

    auto input = codeInput(.useSpaces(2));
    auto clipboard = clipboardChain();
    auto root = chain(clipboard, input);
    root.draw();

    clipboard.value = "World";
    input.push("  Hello,");
    input.push(" ");
    input.paste();
    input.push("!");
    assert(input.value == "  Hello, World!");

    // Undo the exclamation mark
    input.undo();
    assert(input.value == "  Hello, World");

    // Next undo moves before pasting, just like above
    input.undo();
    assert(input.value == "  Hello, ");
    assert(input.valueBeforeCaret == input.value);

    input.undo();
    assert(input.value == "");

    // No change
    input.undo();
    assert(input.value == "");

    input.redo();
    assert(input.value == "  Hello, ");
    assert(input.valueBeforeCaret == input.value);

}

@("CodeInput.paste strips common indent, even if indent character differs from the editor's")
unittest {

    auto input = codeInput(.useTabs);
    auto clipboard = clipboardChain();
    auto root = chain(clipboard, input);
    root.draw();

    clipboard.value = "  foo\n  ";
    input.value = "let foo() {\n\t\n}";
    input.caretIndex = input.value.indexOf("\n}");
    input.paste();
    assert(input.value == "let foo() {\n\tfoo\n\t\n}");

    clipboard.value = "foo\n  bar\n";
    input.value = "let foo() {\n\tx\n}";
    input.caretIndex = input.value.indexOf("x");
    input.paste();
    assert(input.value == "let foo() {\n\tfoo\n\tbar\n\tx\n}");

}
