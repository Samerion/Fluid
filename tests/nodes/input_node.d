module new_io.input_node;

import fluid;

@safe:

alias plainInput = nodeBuilder!PlainInput;

class PlainInput : InputNode!Node {

    override void resizeImpl(Vector2 space) {
        super.resizeImpl(space);
    }

    override void drawImpl(Rectangle outer, Rectangle inner) {
    }

}

@("InputNode.focus() sets focus in FocusIO")
unittest {

    auto input = plainInput();
    auto root = focusChain(input);

    root.draw();
    input.focus();

    assert(root.currentFocus.opEquals(input));

}

@("Disabling a node causes it to block inputs")
unittest {

    int submitted;

    auto btn = button("Hello!", delegate { submitted++; });
    auto root = focusChain(btn);
    root.currentFocus = btn;

    // Press the button
    root.runInputAction!(FluidInputAction.press);
    assert(submitted == 1);

    // Press the button while disabled
    btn.disable();
    root.draw();
    root.runInputAction!(FluidInputAction.press);
    assert(btn.isDisabled);
    assert(btn.blocksInput);
    assert(submitted == 1, "btn shouldn't trigger again");

    // Enable the button and hit it again
    btn.enable();
    root.draw();
    root.runInputAction!(FluidInputAction.press);

    assert(submitted == 2);

}
