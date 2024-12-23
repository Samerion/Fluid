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
    auto hover = hoverSpace(
        .layout!(1, "fill"),
        slot
    );
    auto focus = focusSpace(
        .layout!(1, "fill"),
        hover,
    );
    auto root = focus;

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

@("FieldSlot can \"steal\" hover from non-hoverable child nodes")
version (none)  // TODO
unittest {

    Label theLabel;
    TextInput input;

    // This time around use a vspace, so it won't trigger hover events when pressed outside
    auto slot = fieldSlot!vspace(
        layout!(1, "fill"),
        nullTheme,
        theLabel = label("Hello, World!"),
        input = textInput(),
    );
    auto hover = hoverSpace(
        .layout!(1, "fill"),
        slot,
    );
    auto focus = focusSpace(
        .layout!(1, "fill"),
        hover,
    );
    auto root = focus;
    root.draw();

    // Hover outside
    hover.point(Vector2(500, 500))
        .then((a) {

            assert(hover.hoverOf(a.pointer) is null);
            assert(!hover.isHovered(slot));

            // Cannot press anything
            a.press;

            assert(!hover.isHovered(slot));

            // Hover the label
            return a.move(Vector2(5, 5));

        })
        .then((a) {

            // Press
            a.press;

            return root.nextFrame;

        })
        .then({

            // Focus should be transferred once actions have been processed
            assert(focus.isFocused(input));

        })
        .runWhileDrawing(root);

}
