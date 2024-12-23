module legacy.text_input;

import fluid;

import std.range;
import std.datetime;
import std.algorithm;

@safe:

@("TextInput removes line feeds in single line mode")
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

@("TextInput keeps line feeds in multiline mode")
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

@("TextInput.selectSlice can be used to change the selection in a consistent manner")
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


@("[TODO] Legacy: TextInput resizes to fit text")
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
        return root.contentLabel.getMinSize;
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
    root.value = "This value is long enough to start a new line in the output. To make sure of it, here's "
        ~ "some more text. And more.";
    root.updateSize();
    root.draw();

    assert(textSize.x > root.size.x);
    assert(textSize.x <= 800);
    assert(textSize.y >= root.style.getTypeface.lineHeight * 2);
    assert(root.getMinSize.y >= textSize.y);

}

@("[TODO] Legacy: TextInput accepts text when focused")
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

@("breakLine does nothing in single line TextInput")
unittest {

    auto root = textInput();

    root.push("hello");
    root.runInputAction!(FluidInputAction.breakLine);

    assert(root.value == "hello");

}

@("breakLine creates a new TextInput history entry")
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

@("breakLine interacts well with Unicode text")
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

@("breakLine creates history entries")
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

@("[TODO] Legacy: Single line TextInput submits text when pressing [enter]")
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

@("[TODO] Legacy: ctrl+enter submits, while enter creates a line feed")
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

@("TextInput.chopWord removes last word and chopWord(true) removes next word; chopWord supports Unicode")
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

@("[TODO] Legacy: Cannot type while invoking a keyboard shotcut action")
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

@("FluidInputAction.deleteWord deletes the next word in TextInput")
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

@("FluidInputAction.chop removes last word and chop(true) removes next, supports Unicode")
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

@("[TODO] Legacy: TextInput text can be selected with mouse")
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

@("[TODO] Legacy: Double-click selects words, and triple-click selects lines")
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

@("TextInput.lineByIndex can be used to replace lines")
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

@("TextInput.lineByIndex works well with Unicode")
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

@("TextInput.caretLine returns the current line")
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

@("TextInput.caretLine can be set to change the current line's content")
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

@("TextInput.column can be used to get distance from line start, either in characters or bytes")
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

@("Parts of TextInput text can be iterated with eachLineByIndex")
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

@("textInput.eachLineByIndex can change text and add line feeds during iteration")
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

@("TextInput.eachSelectedLine works with empty text, and suports writing")
unittest {

    auto root = textInput();

    foreach (ref line; root.eachSelectedLine) {
        line = Rope("value");
    }

    assert(root.value == "value");

}

@("[TODO] Legacy: Additional TextInput.chop test")
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

@("[TODO] Legacy: TextInput.chop doesn't affect extracted ropes")
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

@("[TODO] Legacy: TextInput.push doesn't affect previously extracted ropes")
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

@("TextInput.selectWord can be used to select whatever word the caret is touching")
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

@("TextInput.selectLine selects the whole text in single line text inputs")
unittest {

    auto root = textInput();

    root.push("ąąąą ąąą ąąąąąąą ąą\nąąą ąąą");
    assert(root.caretIndex == 49);

    root.selectLine();
    assert(root.selectedValue == root.value);
    assert(root.selectedValue.length == 49);
    assert(root.value.length == 49);

}

@("TextInput.selectLine selects the line the caret is on")
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

@("TextInput.previousWord moves the caret to the previous word")
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

@("previousLine/nextLine keeps the current column in TextInput")
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

@("[TODO] Legacy: TextInput.caretTo works")
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

@("[TODO] Legacy: caretToMouse correctly maps mouse coordinates to internal")
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

@("[TODO] Legacy: previousLine/nextLine keep visual column in TextInput")
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

@("TextInput.push replaces and clears selection")
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

@("[TODO] Legacy: TextInput.cut removes text and puts it in the clipboard")
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

@("[TODO] Legacy: TextInput.copy copies text without editing")
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

@("[TODO] Legacy: TextInput.paste inserts text from the clipboard")
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

@("Inserts can be undone with TextInput.undo, and redone with TextInput.redo")
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

@("Movement breaks up inserts into separate TextInput history entries")
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

@("TextInput.selectToEnd selects until a linea break")
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

@("wordFront returns the next word in text and wordBack returns the last word")
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

@("wordFront and wordBack select words, and can select line feeds")
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

@("[TODO] Legacy: TextInput automatically updates scrolling ancestors")
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
