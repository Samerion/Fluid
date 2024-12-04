module new_io.hover_space;

import fluid;

@safe:

@("HoverSpace keeps track of current hover")
unittest {

    int one;
    int two;
    Button incrementOne;
    Button incrementTwo;

    auto root = hoverSpace(
        incrementOne = button("One", delegate { one++; }),
        incrementTwo = button("Two", delegate { two++; }),
    );

    root.draw();
    root.hover(incrementOne);
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

    root.hover(incrementTwo);
    assert(one == 2);
    assert(two == 0);
    assert(root.runInputAction!(FluidInputAction.press));
    assert(one == 2);
    assert(two == 1);
    assert( root.wasInputHandled);

}
