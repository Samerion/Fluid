module nodes.node_slot;

import fluid;

@safe:

@("NodeSlot can be empty")
unittest {

    auto slot = nodeSlot!Node();
    auto root = testSpace(nullTheme, slot);

    assert(slot.value is null);

    root.drawAndAssert(
        slot.doesNotDraw(),
    );
    root.drawAndAssert(
        slot.doesNotDrawChildren(),
    );

}

@("NodeSlot can carry a child")
unittest {

    auto content = label("Hello, World!");
    auto slot = nodeSlot!Label(content);
    auto root = testSpace(nullTheme, slot);

    root.drawAndAssert(
        slot.doesNotDraw(),
        content.draws(),
    );
    root.drawAndAssert(
        slot.drawsChild(content),
    );

}

@("NodeSlot can change content")
unittest {

    auto slot1 = nodeSlot!Label(label("Hello, "));
    auto slot2 = nodeSlot!Label();
    auto root = testSpace(nullTheme, slot1, slot2);

    root.drawAndAssert(
        slot1.drawsChild(slot1.value),
        slot2.doesNotDrawChildren(),
    );

    slot2 = label("World!");

    auto value1 = slot1.value;
    auto value2 = slot2.value;

    root.drawAndAssert(
        slot1.drawsChild(value1),
        slot2.drawsChild(value2),
    );

    slot1.swapSlots(slot2);

    root.drawAndAssert(
        slot1.drawsChild(value2),
        slot2.drawsChild(value1),
    );

}

@("NodeSlot content can be cleared")
unittest {

    auto slot = nodeSlot!Label(label("Woo!"));
    auto root = testSpace(slot);

    root.drawAndAssert(
        slot.drawsChild(slot.value),
    );

    slot.clear();

    root.drawAndAssert(
        slot.doesNotDrawChildren(),
    );

}
