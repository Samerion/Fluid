module nodes.drag_slot;

import fluid; 

@safe:

@("DragSlot ignores gap if the handle is hidden")
unittest {

    import std.algorithm;
    import fluid.theme;

    auto theme = nullTheme.derive(
        rule!DragSlot(gap = 4),
    );
    auto content = label("a");
    auto slot = dragSlot(content);
    auto root = testSpace(theme, slot);
    slot.handle.hide();
    root.draw();
    assert(slot.getMinSize == content.getMinSize);
    root.drawAndAssert(
        content.drawsImage(content.text.texture.chunks[0].image)
            .at(0, 0)
    );

}

