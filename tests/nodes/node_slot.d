module fluid.nodes.node_slot;

import fluid;

@safe:

@("[TODO] Legacy: NodeSlot supports no content")
unittest {

    NodeSlot!Label slot1, slot2;

    auto io = new HeadlessBackend;
    auto root = hspace(
        label("Hello, "),
        slot1 = nodeSlot!Label(.layout!"fill"),
        label(" and "),
        slot2 = nodeSlot!Label(.layout!"fill"),
    );

    slot1 = label("John");
    slot2 = button("Jane", delegate {

        slot1.swapSlots(slot2);

    });

    with (Rule)
    root.theme = nullTheme.derive(
        rule!Label(textColor = color!"000"),
    );
    root.io = io;

    // First frame
    {
        root.draw();

        assert(slot1.value.text == "John");
        assert(slot2.value.text == "Jane");
        assert(slot1.getMinSize == slot1.value.getMinSize);
        assert(slot2.getMinSize == slot2.value.getMinSize);
    }

    // Focus the second button
    {
        io.nextFrame;
        io.press(KeyboardKey.up);

        root.draw();

        assert(root.tree.focus.asNode is slot2.value);
    }

    // Press it
    {
        io.nextFrame;
        io.release(KeyboardKey.up);
        io.press(KeyboardKey.enter);

        root.draw();

        assert(slot1.value.text == "Jane");
        assert(slot2.value.text == "John");
        assert(slot1.getMinSize == slot1.value.getMinSize);
        assert(slot2.getMinSize == slot2.value.getMinSize);
    }

    // Nodes can be unassigned
    {
        io.nextFrame;
        io.release(KeyboardKey.enter);

        slot1.clear();

        root.draw();

        assert(slot1.value is null);
        assert(slot2.value.text == "John");
        assert(slot1.getMinSize == Vector2(0, 0));
        assert(slot2.getMinSize == slot2.value.getMinSize);
    }

    // toRemove should work as well
    {
        io.nextFrame;

        slot2.value.remove();

        root.draw();

        assert(slot1.value is null);
        assert(slot2.value is null);
        assert(slot1.getMinSize == Vector2(0, 0));
        assert(slot2.getMinSize == Vector2(0, 0));
    }

}

