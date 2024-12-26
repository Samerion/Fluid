module nodes.text_input;

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
