module nodes.slot;

import fluid;

@safe:

@("Slot can be empty")
unittest {

    auto slot = slot!Node();
    auto root = testSpace(nullTheme, slot);

    assert(slot.value is null);

    root.drawAndAssert(
        slot.doesNotDrawChildren(),
    );

}

@("Slot can carry a child")
unittest {

    auto content = label("Hello, World!");
    auto slot = slot!Label(content);
    auto root = testSpace(nullTheme, slot);

    root.drawAndAssert(
        content.draws(),
    );
    root.drawAndAssert(
        slot.drawsChild(content),
    );

}

@("Slot can change content")
unittest {

    auto slot1 = slot!Label(label("Hello, "));
    auto slot2 = slot!Label();
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

@("Slot content can be cleared")
unittest {

    auto slot = slot!Label(label("Woo!"));
    auto root = testSpace(slot);

    root.drawAndAssert(
        slot.drawsChild(slot.value),
    );

    slot.clear();

    root.drawAndAssert(
        slot.doesNotDrawChildren(),
    );

}
