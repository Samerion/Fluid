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
    root.focus(incrementOne);
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

    root.focus(incrementTwo);
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
    assert(cast(Node) focus1.focus == button1);
    assert(cast(Node) focus2.focus == button2);

    focus1.runInputAction!(FluidInputAction.press);
    assert(one == 1);
    assert(two == 0);
    focus2.runInputAction!(FluidInputAction.press);
    assert(one == 1);
    assert(two == 1);

}
