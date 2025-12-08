@Migrated
module legacy.code_input;

import fluid;
import legacy;

import std.range;
import std.string;
import std.algorithm;

@safe:

@("Tab inside of CodeInput can indent and outdent")
@Migrated
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

@("CodeInput.toggleHome works with both tabs and spaces")
@Migrated
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

@("CodeInput.paste changes indents to match the current text")
@Migrated
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

@("CodeInput.paste keeps the clipboard as-is if it's composed of spaces or tabs")
@Migrated
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

@("CodeInput.paste replaces the selection")
@Migrated
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

@("CodeInput.paste creates a history entry (single line)")
@Migrated
unittest {

    // Same test as above, but insert a space instead of line break

    auto io = new HeadlessBackend;
    auto root = codeInput(.useSpaces(2));
    root.io = io;

    io.clipboard = "World";
    root.savePush("  Hello,");
    root.savePush(" ");
    root.runInputAction!(FluidInputAction.paste);
    root.savePush("!");
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

@("CodeInput.paste strips common indent, even if indent character differs from the editor's")
@Migrated
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
