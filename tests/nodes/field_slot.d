module nodes.field_slot;

import fluid;

@safe:

@("Clicking in a FieldSlot passes focus to its child")
unittest {

    TextInput input;

    auto slot = fieldSlot!vframe(
        .layout!(1, "fill"),
        label("Hello, World!"),
        input = textInput(),
    );
    auto hover = hoverChain(.layout!(1, "fill"));
    auto focus = focusChain(.layout!(1, "fill"));
    auto root = chain(focus, hover, slot);

    root.draw();

    assert(!input.isFocused);
    assert(slot.inBounds(Rectangle(0, 0, 800, 600), Rectangle(0, 0, 800, 600), Vector2(200, 200)));
    assert(input.focusIO && input.focusIO.opEquals(focus));

    // In this case, clicking anywhere should give the textInput focus
    hover.point(Vector2(200, 200))
        .then((a) {
            assert(a.isHovered(slot));
            a.press();
            return root.nextFrame;
        })
        .then({
            // Focus should be transferred once actions have been processed
            assert(focus.isFocused(input));
        })
        .runWhileDrawing(root);

}
