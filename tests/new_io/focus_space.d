module new_io.focus_space;

import fluid;

@safe:

@("FocusSpace keeps track of current focus")
unittest {

    int one;
    int two;
    Button incrementOne;
    Button incrementTwo;

    auto root = focusSpace(
        incrementOne = button("One", delegate { one++; }),
        incrementTwo = button("Two", delegate { two++; }),
    );

    root.draw();
    root.currentFocus = incrementOne;
    assert(!root.wasInputHandled);
    assert(one == 0);
    assert(two == 0);
    assert(root.runInputAction!(FluidInputAction.press));
    assert( root.wasInputHandled);
    assert(one == 1);
    assert(two == 0);
    assert(root.runInputAction!(FluidInputAction.press));
    assert(one == 2);
    assert(two == 0);

    root.currentFocus = incrementTwo;
    assert(one == 2);
    assert(two == 0);
    assert(root.runInputAction!(FluidInputAction.press));
    assert(one == 2);
    assert(two == 1);
    assert( root.wasInputHandled);

}

@("Multiple nodes can be focused if they belong to different focus spaces")
unittest {

    FocusSpace focus1, focus2;
    Button button1, button2;
    int one, two;

    auto root = vspace(
        focus1 = focusSpace(
            button1 = button("One", delegate { one++; }),
        ),
        focus2 = focusSpace(
            button2 = button("Two", delegate { two++; }),
        ),
    );

    root.draw();
    button1.focus();
    button2.focus();
    assert(button1.isFocused);
    assert(button2.isFocused);
    assert(cast(Node) focus1.currentFocus == button1);
    assert(cast(Node) focus2.currentFocus == button2);

    focus1.runInputAction!(FluidInputAction.press);
    assert(one == 1);
    assert(two == 0);
    focus2.runInputAction!(FluidInputAction.press);
    assert(one == 1);
    assert(two == 1);

}

@("FocusSpace can be nested")
unittest {

    FocusSpace focus1, focus2;
    Button button1, button2;
    int one, two;

    auto root = vspace(
        focus1 = focusSpace(
            button1 = button("One", delegate { one++; }),
            focus2 = focusSpace(
                button2 = button("Two", delegate { two++; }),
            ),
        ),
    );

    root.draw();
    button1.focus();
    button2.focus();

    assert(cast(Node) focus1.currentFocus == button1);
    assert(cast(Node) focus2.currentFocus == button2);

}

@("FocusSpace supports tabbing")
unittest {

    Button[3] buttons;

    auto root = focusSpace(
        buttons[0] = button("One", delegate { }),
        buttons[1] = button("Two", delegate { }),
        buttons[2] = button("Three", delegate { }),
    );
    root.draw();
    buttons[0].focus();
    assert(root.isFocused(buttons[0]));

    root.runInputAction!(FluidInputAction.focusNext);
    root.draw();
    assert(root.isFocused(buttons[1]));

    root.runInputAction!(FluidInputAction.focusNext);
    root.draw();
    assert(root.isFocused(buttons[2]));

    root.runInputAction!(FluidInputAction.focusNext);
    root.draw();
    assert(root.isFocused(buttons[0]));

}
@("FocusSpace supports tabbing (chained)")
unittest {

    Button[3] buttons;

    auto root = focusSpace(
        buttons[0] = button("One", delegate { }),
        buttons[1] = button("Two", delegate { }),
        buttons[2] = button("Three", delegate { }),
    );
    root.draw();
    buttons[0].focus();
    assert(root.isFocused(buttons[0]));

    const frames = root.focusNext
        .then((Node a) => assert(a == buttons[1]))
        .then(()       => root.focusNext)
        .then((Node a) => assert(a == buttons[2]))
        .then(()       => root.focusNext)
        .then((Node a) => assert(a == buttons[0]))
        .runWhileDrawing(root, 5);

    assert(frames == 3);

}

@("FocusSpace automatically focuses first item on tab")
unittest {

    Button[3] buttons;
    auto root = focusSpace(
        buttons[0] = button("One", delegate { }),
        buttons[1] = button("Two", delegate { }),
        buttons[2] = button("Three", delegate { }),
    );

    assert(root.currentFocus is null);

    // Via chains
    root.focusNext()
        .then((Node n) => assert(n == buttons[0]))
        .then(()       => assert(root.isFocused(buttons[0])))
        .runWhileDrawing(root, 1);

    // Via input actions
    root.clearFocus();
    assert(!root.isFocused(buttons[0]));
    root.runInputAction!(FluidInputAction.focusNext);
    root.draw();
    assert(root.isFocused(buttons[0]));

}

@("FocusSpace focuses the last item on shift tab")
unittest {

    Button[3] buttons;
    auto root = focusSpace(
        buttons[0] = button("One", delegate { }),
        buttons[1] = button("Two", delegate { }),
        buttons[2] = button("Three", delegate { }),
    );

    assert(root.currentFocus is null);

    // Via chains
    root.focusPrevious()
        .then((Node n) => assert(n == buttons[2]))
        .then(()       => assert(root.isFocused(buttons[2])))
        .runWhileDrawing(root, 1);

    // Via input actions
    root.clearFocus();
    assert(!root.isFocused(buttons[2]));
    root.runInputAction!(FluidInputAction.focusPrevious);
    root.draw();
    assert(root.isFocused(buttons[2]));

}

