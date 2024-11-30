module nodes.drag_slot;

import fluid; 

@safe:

@("[TODO] Legacy: DragSlot ignores gap if the handle is hidden")
unittest {

    import std.algorithm;

    import fluid.label;
    import fluid.theme;

    auto theme = nullTheme.derive(
        rule(
            gap = 4,
        ),
    );
    auto io = new HeadlessBackend;
    auto content = label("a");
    auto root = dragSlot(theme, content);
    root.io = io;
    root.handle.hide();
    root.draw();

    assert(root.getMinSize == content.getMinSize);
    assert(io.textures.canFind!(a
        => a.position == Vector2(0, 0)
        && a.id == content.text.texture.chunks[0].texture.id));

}
