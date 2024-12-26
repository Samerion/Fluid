module nodes.text_input;

import std.algorithm;

import fluid;

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

@("TextInput resizes to fit text")
unittest {

    auto root = textInput(
        .layout!"fill",
        .multiline,
        .nullTheme,
        "This placeholder exceeds the default size of a text input."
    );

    root.draw();

    Vector2 textSize() {
        return root.contentLabel.getMinSize;
    }

    assert(textSize.x > 200);
    assert(textSize.x > root.size.x);

    root.placeholder = "";
    root.updateSize();
    root.draw();

    assert(root.caretPosition.x < 1);
    assert(textSize.x < 1);

    root.value = "This value exceeds the default size of a text input.";
    root.updateSize();
    root.caretToEnd();
    root.draw();

    assert(root.caretPosition.x > 200);
    assert(textSize.x > 200);
    assert(textSize.x > root.size.x);

    root.value = "This value is long enough to start a new line in the output. To make sure of it, here's "
        ~ "some more text. And more.";
    root.updateSize();
    root.draw();

    assert(textSize.x > root.size.x);
    assert(textSize.x <= 800);
    assert(textSize.y >= root.style.getTypeface.lineHeight * 2);
    assert(root.getMinSize.y >= textSize.y);

}

@("TextInput accepts text when focused")
unittest {

    auto input = textInput("placeholder");
    auto focus = focusChain();
    auto root = chain(focus, input);

    // Empty text
    {
        root.draw();

        assert(input.value == "");
        assert(input.contentLabel.text == "placeholder");
        assert(input.isEmpty);
    }

    // Focus the box and input stuff
    {
        focus.typeText("¡Hola, mundo!");
        focus.currentFocus = input;
        root.draw();

        assert(input.value == "¡Hola, mundo!");
    }

    // The text will be displayed the next frame
    {
        root.draw();

        assert(input.contentLabel.text == "¡Hola, mundo!");
        assert(input.isFocused);
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

@("Single line TextInput submits text when pressing Enter")
unittest {

    int submitted;

    auto map = InputMapping();
    map.bindNew!(FluidInputAction.breakLine)(KeyboardIO.codes.enter);
    map.bindNew!(FluidInputAction.submit)(KeyboardIO.codes.enter);
    map.bindNew!(FluidInputAction.breakLine)(KeyboardIO.codes.enter);

    TextInput input;
    input = textInput("placeholder", delegate {
        submitted++;
        assert(input.value == "Hello World");
    });

    auto focus = focusChain();
    auto root = chain(
        inputMapChain(map),
        focus,
        input,
    );

    // Type stuff
    focus.currentFocus = input;
    input.value = "Hello World";
    root.draw();
    assert(submitted == 0);
    assert(input.value == "Hello World");
    assert(input.contentLabel.text == "Hello World");

    // Submit
    focus.emitEvent(KeyboardIO.press.enter);
    root.draw();
    assert(submitted == 1);

}

@("Ctrl+Enter submits, while Enter creates a line feed")
unittest {

    auto map = InputMapping();
    map.bindNew!(FluidInputAction.breakLine)(KeyboardIO.codes.enter);
    map.bindNew!(FluidInputAction.submit)(KeyboardIO.codes.enter);
    map.bindNew!(FluidInputAction.breakLine)(KeyboardIO.codes.enter);
    map.bindNew!(FluidInputAction.submit)(KeyboardIO.codes.leftControl, KeyboardIO.codes.enter);

    int submitted;
    auto input = multilineInput("", delegate { submitted++; });
    auto focus = focusChain();
    auto root = chain(
        inputMapChain(map),
        focus,
        input,
    );

    // Type text
    focus.currentFocus = input;
    input.push("Hello, World!");
    root.draw();

    // Press enter to create a line feed
    focus.emitEvent(KeyboardIO.press.enter);
    root.draw();
    assert(input.value == "Hello, World!\n");
    assert(submitted == 0);

    // TextInput should ignore typed line feeds in this scenario
    focus.typeText("\n");
    focus.emitEvent(KeyboardIO.press.enter);
    root.draw();
    assert(input.value == "Hello, World!\n\n");
    assert(submitted == 0);

    // Press Ctrl+Enter
    focus.emitEvent(KeyboardIO.press.leftControl);
    focus.emitEvent(KeyboardIO.press.enter);
    root.draw();

    // Input should be submitted
    assert(input.value == "Hello, World!\n\n");
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


@("Cannot type while invoking a keyboard shortcut action")
unittest {

    auto map = InputMapping();
    map.bindNew!(FluidInputAction.backspaceWord)(KeyboardIO.codes.w);

    auto input = textInput();
    auto focus = focusChain();
    auto root = chain(
        inputMapChain(map),
        focus,
        input,
    );

    // Type stuff
    focus.currentFocus = input;
    input.value = "Hello ";
    input.caretToEnd();
    root.draw();
    assert(input.value == "Hello ");

    // Typing should be disabled while erasing
    focus.emitEvent(KeyboardIO.press.w);
    focus.typeText("w");
    root.draw();

    assert(input.value == "");
    assert(input.isEmpty);

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

@("TextInput.eachLineByIndex works with single lines of text")
unittest {

    auto root = textInput();
    root.value = "test";

    size_t i;
    foreach (line; root.eachLineByIndex(1, 4)) {

        assert(i++ == 0);
        assert(line == "test");

    }

}

@("TextInput.eachSelectedLine works with empty text")
unittest {

    bool done;
    auto root = textInput();

    foreach (line; root.eachSelectedLine) {
        done = true;
        assert(line == "");
    }

    assert(done);

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
