module legacy.text_input;

import fluid;
import legacy;

import std.range;
import std.datetime;
import std.algorithm;

import text.text;

@safe:

@("TextInput accepts text when focused")
@Migrated
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

@("Single line TextInput submits text when pressing enter")
@Migrated
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

@("ctrl+enter submits, while enter creates a line feed")
@Migrated
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

@("Cannot type while invoking a keyboard shortcut action")
@Migrated
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

@("TextInput text can be selected with mouse")
@Migrated
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

@("Double-click selects words, and triple-click selects lines")
@Migrated
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

@("textInput.eachLineByIndex can change text and add line feeds during iteration")
@Abandoned
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

@("TextInput.eachLineByIndex returns correct results when edited")
@Abandoned
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

@("TextInput.eachLineByIndex allows multiple edits per line")
@Abandoned
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

@("TextInput.eachLineByIndex works with single lines of text")
@Migrated
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

@("TextInput.eachSelectedLine works with empty text, and supports writing")
@Migrated
unittest {

    auto root = textInput();

    foreach (ref line; root.eachSelectedLine) {
        line = Rope("value");
    }

    assert(root.value == "value");

}

@("Additional TextInput.chop test")
@Migrated
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

@("TextInput.chop doesn't affect extracted ropes")
@Migrated
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
    assert(value1  == "Hello, World!");

    auto value3 = root.value;
    root.clear();

    assert(root.value == "");
    assert(value3  == "Hello, ");
    assert(value2  == "Hello, World");
    assert(value1  == "Hello, World!");

}

@("TextInput.push doesn't affect previously extracted ropes")
@Migrated
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
    assert(value3 == "Hello, Moon");
    assert(value2 == "Hello, ");
    assert(value1 == "Hello, World");

}

@("TextInput.caretTo works")
@Migrated
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
    assert(root.caretRectangle.x.isClose(0));
    assert(root.caretRectangle.y.isClose(135));

    root.updateCaretPosition(false);
    assert(root.caretRectangle.x.isClose(153));
    assert(root.caretRectangle.y.isClose(108));

    // Try the same with the third line
    root.caretTo(Vector2(200, 148));
    assert(root.caretIndex
        == "Hello, World!\nHello, Moon\n\nHello, Sun\nWrap this line µp, make it long enough ".length);
    root.caretTo(Vector2(2, 168));
    assert(root.caretIndex
        == "Hello, World!\nHello, Moon\n\nHello, Sun\nWrap this line µp, make it long enough ".length);

}

@("caretToMouse correctly maps mouse coordinates to internal")
@Migrated
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

@("previousLine/nextLine keep visual column in TextInput")
@Migrated
unittest {

    // Note: This test depends on parameters specific to the default typeface.

    import std.math : isClose;

    auto io = new HeadlessBackend;
    auto root = textInput(.testTheme, .multiline);

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
    assert(root.caretRectangle.x.isClose(0));

    // Move to the previous line
    root.runInputAction!(FluidInputAction.previousLine);

    assert(root.valueBeforeCaret.wordBack == ", ");
    assert(root.valueAfterCaret.wordFront == "make ");
    assert(root.caretRectangle.x.isClose(0));

    // Move to its end — position should be the same as earlier, but the caret should be on the same line
    root.runInputAction!(FluidInputAction.toLineEnd);

    assert(root.valueBeforeCaret.wordBack == "enough ");
    assert(root.valueAfterCaret.wordFront == "to ");
    assert(root.caretRectangle.x.isClose(181));

    // Move to the previous line — again
    root.runInputAction!(FluidInputAction.previousLine);

    assert(root.valueBeforeCaret.wordBack == ", ");
    assert(root.valueAfterCaret.wordFront == "make ");
    assert(root.caretRectangle.x.isClose(153));

}


@("TextInput.cut removes text and puts it in the clipboard")
@Migrated
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

@("TextInput.cut works with Unicode")
@Migrated
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

@("TextInput.copy copies text without editing")
@Migrated
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

@("TextInput.paste inserts text from the clipboard")
@Migrated
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

@("TextInput automatically updates scrolling ancestors")
@Migrated
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

    assert(focusBox.start == input.caretRectangle.start);
    assert(focusBox.end.y - viewportHeight == root.scroll);


}

@("TextInput.toLineStart and TextInput.toLineEnd work and correctly set horizontal anchors")
unittest {

    // Note: This test depends on parameters specific to the default typeface.

    import std.math : isClose;

    auto io = new HeadlessBackend;
    auto root = textInput(.testTheme, .multiline);

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
    assert(root.caretRectangle.x.isClose(0));

    // Move to the previous line
    root.runInputAction!(FluidInputAction.previousLine);

    assert(root.valueBeforeCaret.wordBack == ", ");
    assert(root.valueAfterCaret.wordFront == "make ");
    assert(root.caretRectangle.x.isClose(0));

    // Move to its end — position should be the same as earlier, but the caret should be on the same line
    root.runInputAction!(FluidInputAction.toLineEnd);

    assert(root.valueBeforeCaret.wordBack == "enough ");
    assert(root.valueAfterCaret.wordFront == "to ");
    assert(root.caretRectangle.x.isClose(181));

    // Move to the previous line — again
    root.runInputAction!(FluidInputAction.previousLine);

    assert(root.valueBeforeCaret.wordBack == ", ");
    assert(root.valueAfterCaret.wordFront == "make ");
    assert(root.caretRectangle.x.isClose(153));

}
