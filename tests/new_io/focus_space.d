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
