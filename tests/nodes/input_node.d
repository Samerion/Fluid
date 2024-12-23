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
    auto root = focusSpace(input);

    root.draw();
    input.focus();

    assert(root.currentFocus.opEquals(input));

}

@("Disabling a node causes it to block inputs")
unittest {

    int submitted;

    auto btn = button("Hello!", delegate { submitted++; });
    auto root = focusSpace(btn);
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

    assert(!btn.isDisabledInherited);
    assert(submitted == 2);

}

@("[TODO] Disabled nodes cannot accept text input")
version (none)
unittest {

    // TODO use a dedicated node instead of text input

    auto input = textInput("Placeholder", delegate { });
    auto root = focusSpace(input);
    root.currentFocus = input;

    // Try typing into the input box
    root.type("Hello, ");
    assert(input.value == "Hello, ");

    // Disable the box and try typing again
    input.disable();
    root.type("World!");

    assert(input.value == "Hello, ", "Input should remain unchanged");

}
