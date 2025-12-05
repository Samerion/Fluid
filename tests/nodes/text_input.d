module nodes.text_input;

import std.algorithm;

import fluid;
import text.text;

@safe:

@("TextInput scrolls when there is too much text to fit in its width")
unittest {

    auto input = textInput(.testTheme);
    auto root = testSpace(input);

    input.value = "correct horse battery staple";
    root.draw();
    input.caretToEnd();

    root.drawAndAssert(
        input.drawsRectangle(0, 0, 200, 27).ofColor("#faf"),
        input.cropsTo       (0, 0, 200, 27),
        input.contentLabel.drawsHintedImage().at(-42, 0),
    );

}

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

    assert(root.caretRectangle.x < 1);
    assert(textSize.x < 1);

    root.value = "This value exceeds the default size of a text input.";
    root.updateSize();
    root.caretToEnd();
    root.draw();

    assert(root.caretRectangle.x > 200);
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

    root.savePush("hello");
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

@("TextInput.breakLine creates its own history entry")
unittest {

    auto root = textInput(.multiline);
    root.savePush("first line");
    root.runInputAction!(FluidInputAction.breakLine);
    root.savePush("second line");
    root.runInputAction!(FluidInputAction.breakLine);
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
    root.savePush("Hello, ");
    root.runInputAction!(FluidInputAction.breakLine);
    root.savePush("new");
    root.runInputAction!(FluidInputAction.breakLine);
    root.savePush("line");
    root.runInputAction!(FluidInputAction.backspace);
    root.runInputAction!(FluidInputAction.backspaceWord);
    root.savePush("few");
    root.savePush(" lines");
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
    assert(root.value == "Hello, \nnew\nlin");
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
    assert(root.value == "Hello, \nnew\nlin");
    root.redo();
    assert(root.value == "Hello, \nnew\n");
    root.redo();
    assert(root.value == "Hello, \nnew\nfew lines");

    // Navigate and replace "Hello"
    root.caretIndex = 5;
    root.runInputAction!(FluidInputAction.selectPreviousWord);
    root.savePush("Hi");
    assert(root.value == "Hi, \nnew\nfew lines");
    assert(root.valueBeforeCaret == "Hi");

    root.undo();
    assert(root.value == "Hello, \nnew\nfew lines");
    assert(root.selectedValue == "Hello");

    root.undo();
    assert(root.value == "Hello, \nnew\n");
    assert(root.valueAfterCaret == "");

}

@("History entries do not merge if the caret has moved")
unittest {

    auto root = textInput();

    foreach (i; "dcba") {
        root.caretToStart();
        root.savePush(i);
    }

    assert(root.value == "abcd");
    assert(root.valueBeforeCaret == "a");
    root.undo();
    assert(root.value == "bcd");
    assert(root.valueBeforeCaret == "");
    root.undo();
    assert(root.value == "cd");
    assert(root.valueBeforeCaret == "");
    root.undo();
    assert(root.value == "d");
    assert(root.valueBeforeCaret == "");
    root.undo();
    assert(root.value == "");

}

@("TextInput.selectToEnd selects until a line break")
unittest {

    auto root = textInput(.testTheme, .multiline);

    root.value = "First one\nSecond two";
    root.draw();

    auto lineHeight = root.style.getTypeface.lineHeight;

    // Navigate to the start and select the whole line
    root.caretToStart();
    root.runInputAction!(FluidInputAction.selectToLineEnd);

    assert(root.selectedValue == "First one");
    assert(root.caretRectangle.center.y < lineHeight);

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

@("TextInput.chop supports unicode")
unittest {

    auto root = textInput();

    // Type stuff
    root.value = "hello‽";
    root.caretToEnd();
    root.draw();

    assert(root.value == "hello‽");
    assert(root.contentLabel.text == "hello‽");

    // Erase a letter
    root.chop;
    root.draw();
    assert(root.value == "hello");
    assert(root.contentLabel.text == "hello");

    // Erase a letter
    root.chop;
    root.draw();
    assert(root.value == "hell");
    assert(root.contentLabel.text == "hell");

}

@("TextInput.chop/chopWord/clear don't affect extracted ropes")
unittest {

    auto root = textInput();

    root.push("Hello, World!");
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

@("TextInput.chopWord/push doesn't affect extracted ropes")
unittest {

    auto root = textInput();

    root.push("Hello, World");
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
unittest {

    // Note: This test depends on parameters specific to the default typeface.

    import std.math : isClose;

    auto root = textInput(.nullTheme, .multiline);
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

@("previousLine/nextLine keep visual column in TextInput")
unittest {

    // Note: This test depends on parameters specific to the default typeface.

    import std.math : isClose;

    auto root = textInput(.nullTheme, .multiline);
    root.size = Vector2(200, 0);
    root.value = "Hello, World!\nHello, Moon\n\nHello, Sun\nWrap this line µp, make it long enough to cross over";
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

@("TextInput automatically updates scrolling ancestors")
unittest {

    // Note: This theme relies on properties of the default typeface

    import fluid.scroll;

    const viewportWidth = 200;
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
    auto root = sizeLock!vscrollFrame(
        .sizeLimit(viewportWidth, viewportHeight),
        theme,
        input
    );

    root.draw();
    assert(root.scroll == 0);

    // Begin typing
    input.push("FLUID\nIS\nAWESOME");
    input.caretToStart();
    input.push("FLUID\nIS\nAWESOME\n");
    root.draw();
    root.draw();

    const focusBox = input.focusBoxImpl(Rectangle(0, 0, viewportWidth, viewportHeight));

    assert(focusBox.start == input.caretRectangle.start);
    assert(focusBox.end.y - viewportHeight == root.scroll);

}

@("TextInput text can be selected with mouse")
unittest {

    // This test relies on properties of the default typeface

    import std.math : isClose;

    auto input = textInput();
    auto hover = hoverChain();
    auto root = testSpace(
        .testTheme,
        chain(inputMapChain(), hover, input)
    );
    input.value = "Hello, World! Foo, bar, scroll this input";
    input.caretToEnd();
    root.draw();

    assert(input.scroll.isClose(127));

    // Select some stuff
    hover.point(150, 10)
        .then((a) {
            a.press(false);
            return a.move(65, 10);
        })
        .then((a) {
            a.press(false);
            assert(input.selectedValue == "scroll this");
        })
        .runWhileDrawing(root);

    // Match the selection box
    root.drawAndAssert(
        input.drawsRectangle(64, 0, 86, 27).ofColor("#02a")
    );

}

@("Double-click selects words, and triple-click selects lines")
unittest {

    // This test relies on properties of the default typeface

    import std.math : isClose;

    auto input = textInput(nullTheme);
    auto hover = hoverChain();
    auto root = chain(hover, input);
    input.value = "Hello, World! Foo, bar, scroll this input";
    input.caretToEnd();
    root.draw();

    hover.point(150, 10)
        .then((action) {

            // Double- and triple-click
            foreach (i; 0..3) {

                assert(action.isHovered(input));

                action.press(true, i+1);
                root.draw();

                // Double-clicked
                if (i == 1) {
                    assert(input.selectedValue == "this");
                }

                // Triple-clicked
                if (i == 2) {
                    assert(input.selectedValue == input.value);
                }

            }

        })
        .runWhileDrawing(root);

    assert(input.selectedValue == input.value);

}

@("caretToPointer correctly maps mouse coordinates to internal")
unittest {

    import std.math : isClose;

    // caretToMouse is a just a wrapper over caretTo, enabling mouse input
    // This test checks if it correctly maps mouse coordinates to internal coordinates

    auto theme = nullTheme.derive(
        rule!TextInput(
            Rule.margin = 40,
            Rule.padding = 40,
        )
    );
    auto input = textInput(.multiline, theme);
    auto hover = hoverChain();
    auto root = chain(hover, input);
    input.size = Vector2(200, 0);
    input.value = "123\n456\n789";
    root.draw();

    assert(input.caretIndex == 0);

    hover.point(140, 90)
        .then((a) {
             input.caretToPointer(a.pointer);
        })
        .runWhileDrawing(root);

    assert(input.caretIndex == 3);

}

@("TextInput.cut removes text and puts it in the clipboard")
unittest {

    auto input = textInput();
    auto root = clipboardChain(input);

    root.draw();
    input.push("Foo Bar Baz Ban");

    // Move cursor to "Bar"
    input.runInputAction!(FluidInputAction.toStart);
    input.runInputAction!(FluidInputAction.nextWord);

    // Select "Bar Baz "
    input.runInputAction!(FluidInputAction.selectNextWord);
    input.runInputAction!(FluidInputAction.selectNextWord);

    assert(root.value == "");
    assert(input.selectedValue == "Bar Baz ");

    // Cut the text
    input.cut();

    assert(root.value == "Bar Baz ");
    assert(input.value == "Foo Ban");

}

@("TextInput.cut works with Unicode")
unittest {

    auto input = textInput();
    auto clipboard = clipboardChain(input);
    auto root = clipboard;

    input.push("Привет, мир! Это пример текста для тестирования поддержки Unicode во Fluid.");
    root.draw();
    clipboard.value = "ą";

    input.runInputAction!(FluidInputAction.previousChar);
    input.selectionStart = 106;  // Before "Unicode"
    input.cut();

    assert(input.value == "Привет, мир! Это пример текста для тестирования поддержки .");
    assert(clipboard.value == "Unicode во Fluid");

    input.caretIndex = 14;
    input.runInputAction!(FluidInputAction.selectNextWord);  // мир
    input.paste();

    assert(input.value == "Привет, Unicode во Fluid! Это пример текста для тестирования поддержки .");

}

@("TextInput.copy copies text without editing")
unittest {

    auto input = textInput();
    auto clipboard = clipboardChain(input);
    auto root = clipboard;

    root.draw();
    input.push("Foo Bar Baz Ban");
    input.selectAll();
    assert(clipboard.value == "");

    input.copy();
    assert(clipboard.value == "Foo Bar Baz Ban");

    // Reduce selection by a word
    input.runInputAction!(FluidInputAction.selectPreviousWord);
    input.copy();

    assert(clipboard.value == "Foo Bar Baz ");
    assert(input.value == "Foo Bar Baz Ban");

}

@("TextInput.paste inserts text from the clipboard")
unittest {

    auto input = textInput();
    auto clipboard = clipboardChain(input);
    auto root = clipboard;

    input.value = "Foo ";
    root.draw();
    input.caretToEnd();
    clipboard.value = "Bar";
    assert(input.caretIndex == 4);
    assert(input.value == "Foo ");

    input.paste();
    assert(input.caretIndex == 7);
    assert(input.value == "Foo Bar");

    input.caretToStart();
    input.paste();
    assert(input.caretIndex == 3);
    assert(input.value == "BarFoo Bar");

}

@("TextInput read large amounts of text at once")
unittest {

    import std.array;
    import std.range : repeat;

    immutable(char)[4096] content = 'a';

    auto input = textInput();
    auto focus = focusChain();
    auto root = chain(focus, input);
    root.draw();

    focus.currentFocus = input;
    focus.typeText(content[]);
    root.draw();

    assert(input.value == content);

}

@("TextInput.paste supports clipboard with lots of content")
unittest {

    import std.array;
    import std.range : repeat;

    immutable(char)[4096] content = 'a';

    auto input = textInput();
    auto clipboard = clipboardChain();
    auto root = chain(clipboard, input);
    clipboard.value = content[];
    root.draw();

    input.paste();
    assert(input.value == content);

}

@("TextInput: Mouse selections works correctly across lines")
unittest {

    import std.math : isClose;

    auto input = textInput(.multiline, .testTheme);
    auto hover = hoverChain();
    auto root = chain(inputMapChain(), hover, input);

    input.value = "Line one\nLine two\n\nLine four";
    root.draw();

    auto lineHeight = input.style.getTypeface.lineHeight;

    // Move the caret to second line
    input.caretIndex = "Line one\nLin".length;
    input.updateCaretPosition();

    const middle = input.caretRectangle.center;
    const top    = middle - Vector2(0, lineHeight);
    const blank  = middle + Vector2(0, lineHeight);
    const bottom = middle + Vector2(0, lineHeight * 2);

    // Press in the middle and drag to the top
    hover.point(middle)
        .then((a) {
            a.press(false);
            return a.move(top);
        })

        // Check results; move to bottom
        .then((a) {
            a.press(false);
            assert(input.selectedValue == "e one\nLin");
            assert(input.selectionStart > input.selectionEnd);
            return a.move(bottom);
        })

        // Now move to the blank line
        .then((a) {
            a.press(false);
            assert(input.selectedValue == "e two\n\nLin");
            assert(input.selectionStart < input.selectionEnd);
            return a.move(blank);
        })
        .then((a) {
            a.press(true);
            assert(input.selectedValue == "e two\n");
            assert(input.selectionStart < input.selectionEnd);
        })
        .runWhileDrawing(root);

}

@("TextInput: Mouse selections can select words by double clicking")
unittest {

    auto input = textInput(.multiline, .testTheme);
    auto hover = hoverChain();
    auto root = chain(inputMapChain(), hover, input);

    input.value = "Line one\nLine two\n\nLine four";
    root.draw();

    auto lineHeight = input.style.getTypeface.lineHeight;

    // Move the caret to second line
    input.caretIndex = "Line one\nLin".length;
    input.updateCaretPosition();

    const middle = input.caretPosition;
    const top    = middle - Vector2(0, lineHeight);
    const blank  = middle + Vector2(0, lineHeight);
    const bottom = middle + Vector2(0, lineHeight * 2);

    // Double click in the middle
    hover.point(middle)
        .then((a) {
            a.doubleClick(false);
            assert(input.selectedValue == "Line");
            assert(input.selectionStart < input.selectionEnd);

            // Drag the pointer to top row
            return a.move(top);
        })
        .then((a) {
            a.doubleClick(false);
            assert(input.selectedValue == "Line one\nLine");
            assert(input.selectionStart > input.selectionEnd);

            // Bottom row
            return a.move(bottom);
        })
        .then((a) {
            a.doubleClick(false);
            assert(input.selectedValue == "Line two\n\nLine");
            assert(input.selectionStart < input.selectionEnd);

            // And now drag the pointer to the blank line
            return a.move(blank);
        })
        .then((a) {
            a.doubleClick(true);
        })
        .runWhileDrawing(root);

    assert(input.selectedValue == "Line two\n");
    assert(input.selectionStart < input.selectionEnd);

}

@("TextInput: Mouse selections can select words by triple clicking")
unittest {

    auto input = textInput(.multiline, .testTheme);
    auto hover = hoverChain();
    auto root = chain(inputMapChain(), hover, input);

    input.value = "Line one\nLine two\n\nLine four";
    root.draw();

    auto lineHeight = input.style.getTypeface.lineHeight;

    // Move the caret to second line
    input.caretIndex = "Line one\nLin".length;
    input.updateCaretPosition();

    const middle = input.caretPosition;
    const top    = middle - Vector2(0, lineHeight);
    const blank  = middle + Vector2(0, lineHeight);
    const bottom = middle + Vector2(0, lineHeight * 2);

    hover.point(middle)
        .then((a) {
            a.tripleClick(false);
            assert(input.selectedValue == "Line two");
            assert(input.selectionStart < input.selectionEnd);

            return a.move(top);
        })
        .then((a) {
            a.tripleClick(false);
            assert(input.selectedValue == "Line one\nLine two");
            assert(input.selectionStart > input.selectionEnd);

            return a.move(bottom);
        })
        .then((a) {
            a.tripleClick(false);
            assert(input.selectedValue == "Line two\n\nLine four");
            assert(input.selectionStart < input.selectionEnd);

            return a.move(blank);
        })
        .then((a) {
            a.tripleClick(true);
        })
        .runWhileDrawing(root);

    assert(input.selectedValue == "Line two\n");
    assert(input.selectionStart < input.selectionEnd);

}

@("TextInput selection displays correctly in HiDPI")
unittest {

    auto node = multilineInput(.testTheme);
    auto root = testSpace(node);

    // Matsuo Bashō "The Old Pond"
    node.value = "Old pond...\n"
        ~ "a frog jumps in\n"
        ~ "water's sound\n";
    node.selectSlice(4, 33);

    // 100% scale
    root.drawAndAssert(
        node.drawsRectangle(0, 0, 200, 108).ofColor("#ffaaff"),
        node.cropsTo(0, 0, 200, 108),

        // Selection
        node.drawsRectangle(33, 0, 59, 27).ofColor("#0022aa"),
        node.drawsRectangle(0, 27, 128, 27).ofColor("#0022aa"),
        node.drawsRectangle(0, 54, 50, 27).ofColor("#0022aa"),

        node.contentLabel.isDrawn().at(0, 0, 200, 108),
        node.contentLabel.drawsHintedImage().at(0, 0, 1024, 1024).ofColor("#ffffff")
            .sha256("7033f92fce5cf825ab357b1514628504361399d20ce47e2966ed86cacc45cf3a"),
    );

    // 125% scale
    root.setScale(1.25);
    root.drawAndAssert(

        // Selection
        node.drawsRectangle(33.6, 0, 57.6, 26.4).ofColor("#0022aa"),
        node.drawsRectangle(0, 26.4, 128.8, 26.4).ofColor("#0022aa"),
        node.drawsRectangle(0, 52.8, 48.8, 26.4).ofColor("#0022aa"),

        node.contentLabel.isDrawn().at(0, 0, 200, 106),
        node.contentLabel.drawsHintedImage().at(0, 0, 819.2, 819.2).ofColor("#ffffff")
            .sha256("2c72029c85ba28479d2089456261828dfb046c1be134b46408740b853e352b90"),
    );

}

@("TextInput pointer position is correctly recognized in HiDPI")
unittest {

    auto node = multilineInput(.testTheme);
    auto focus = focusChain(node);
    auto root = testSpace(focus);

    focus.currentFocus = node;

    // Matsuo Bashō "The Old Pond"
    node.value = "Old pond...\n"
        ~ "a frog jumps in\n"
        ~ "water's sound\n";

    // Warning: There is some kind of precision loss going on here
    foreach (i, scale; [1.00, 1.25]) {
        root.setScale(scale);
        root.draw();

        node.caretTo(Vector2(36, 10));
        node.updateCaretPosition();
        assert(node.caretIndex == 4);
        root.drawAndAssert(
            i == 0
                ? node.drawsLine().from(33.0, 2.70).to(33.0, 24.30).ofWidth(1).ofColor("#000000")
                : node.drawsLine().from(33.6, 2.64).to(33.6, 23.76).ofWidth(1).ofColor("#000000"),
        );

        node.caretTo(Vector2(47, 66));
        node.updateCaretPosition();
        assert(node.caretIndex == 33);
        root.drawAndAssert(
            i == 0
                ? node.drawsLine().from(50.0, 56.70).to(50.0, 78.30).ofWidth(1).ofColor("#000000")
                : node.drawsLine().from(48.8, 55.44).to(48.8, 76.56).ofWidth(1).ofColor("#000000"),
        );
    }

}

@("TextInput scrolling works correctly in HiDPI")
unittest {

    enum textConstant = " one two three four";

    auto node = lineInput();
    auto root = testSpace(.testTheme, node);
    root.setScale(1.25);
    root.draw();

    node.push(textConstant);
    root.drawAndAssert(
        node.isDrawn().at(0, 0, 200, 27),
        node.drawsRectangle(0, 0, 200, 27).ofColor("#ffaaff"),
        node.cropsTo(0, 0, 200, 27),
        node.contentLabel.drawsHintedImage().at(0, 0, 819.2, 819.2).ofColor("#ffffff")
            .sha256("f8e7558a9641e24bb5cb8bb49c27284d87436789114e2f875e2736b521fe170e"),
        node.contentLabel.doesNotDraw(),
    );

    foreach (_; 0..5) {
        node.push(textConstant);
    }
    root.drawAndAssert(
        node.cropsTo(0, 0, 200, 27),
        node.contentLabel.isDrawn().at(-784, 0, 984, 27),
        node.contentLabel.drawsHintedImage().at(-784, 0, 819.2, 819.2).ofColor("#ffffff")
            .sha256("01f6ca34c8a7cda32d38daac9938031a5b16020e8fed3aca0f4748582c787de8"),
        node.contentLabel.drawsHintedImage().at(35.2, 0, 819.2, 819.2).ofColor("#ffffff")
            .sha256("9fa7e5f27e1ad1d7c21efa837f94ab241b3f4b4401c61841720eb40c5ff859cc"),
    );

    foreach (_; 0..4) {
        node.push(textConstant);
    }
    root.drawAndAssert(
        node.cropsTo(0, 0, 200, 27),
        node.contentLabel.isDrawn().at(-1440, 0, 1640, 27),
        node.contentLabel.drawsHintedImage().at(-620.8, 0, 819.2, 819.2).ofColor("#ffffff")
            .sha256("e4910bc3700d464f172425e266ea918ec88f6a6c0d42b6cbeed396e9f22fb5df"),
        node.contentLabel.drawsHintedImage().at(198.4, 0, 819.2, 819.2).ofColor("#ffffff")
            .sha256("bb017d2518a0b78fe37ba7aa231553806dbb9f6a8aaff8a84fedb8b4b704025d"),
    );

}

@("TextInput displays a blinking caret only when focused")
unittest {

    auto input = textInput();
    auto time = timeMachine(input);
    auto focus = focusChain(time);
    auto root = testSpace(.testTheme, focus);

    root.draw();
    focus.currentFocus = input;

    foreach (i; 0..4) {

        // First half of the blank interval: caret visible
        assert( input.isCaretVisible);
        root.drawAndAssert(
            input.drawsLine().from(0, 2.7).to(0, 24.3),
        );
        time += input.blinkInterval / 4;
        assert( input.isCaretVisible);
        root.drawAndAssert(
            input.drawsLine().from(0, 2.7).to(0, 24.3),
        );
        time += input.blinkInterval / 4;

        // Second half of the blank interval: caret hidden
        assert(!input.isCaretVisible);
        root.drawAndAssertFailure(
            input.drawsLine(),
        );
        time += input.blinkInterval / 4;
        assert(!input.isCaretVisible);
        root.drawAndAssertFailure(
            input.drawsLine(),
        );
        time += input.blinkInterval / 4;

    }

}

@("Caret isn't drawn when TextInput isn't focused")
unittest {

    auto input = textInput();
    auto time = timeMachine(input);
    auto focus = focusChain(time);
    auto root = testSpace(.testTheme, focus);

    root.draw();

    foreach (i; 0..8) {

        time += input.blinkInterval / 4;
        root.drawAndAssertFailure(
            input.drawsLine(),
        );
        assert(!input.isCaretVisible);

    }

}
