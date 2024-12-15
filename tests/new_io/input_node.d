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
