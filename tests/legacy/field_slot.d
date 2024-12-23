module legacy.field_slot;

import fluid;
import legacy;

@safe:

@("Clicking in a FieldSlot passes focus to its child")
@Migrated
unittest {

    TextInput input;

    auto io = new HeadlessBackend;
    auto root = fieldSlot!vframe(
        layout!"fill",
        label("Hello, World!"),
        input = textInput(),
    );

    root.io = io;
    root.draw();

    assert(!input.isFocused);

    // In this case, clicking anywhere should give the textInput focus
    io.nextFrame;
    io.mousePosition = Vector2(200, 200);
    io.press;
    root.draw();

    assert(root.tree.hover is root);

    // Trigger the event
    io.nextFrame;
    io.release;
    root.draw();

    // Focus should be transferred once actions have been processed
    io.nextFrame;
    root.draw();

    assert(input.isFocused);

}

@("FieldSlot can take hover from non-hoverable child nodes")
unittest {

    import fluid.space;
    import fluid.label;
    import fluid.structs;
    import fluid.text_input;
    import fluid.default_theme;

    Label theLabel;
    TextInput input;

    // This time around use a vspace, so it won't trigger hover events when pressed outside
    auto io = new HeadlessBackend;
    auto root = fieldSlot!vspace(
        layout!"fill",
        nullTheme,
        theLabel = label("Hello, World!"),
        input = textInput(),
    );

    root.io = io;
    root.draw();

    assert(!input.isFocused);

    // Hover outside
    io.nextFrame;
    io.mousePosition = Vector2(500, 500);
    root.draw();

    assert(root.tree.hover is null);

    // Hover the label
    io.nextFrame;
    io.mousePosition = Vector2(5, 5);
    io.press;
    root.draw();

    // The root should take the hover
    assert(theLabel.isHovered);
    assert(root.tree.hover is root);

    // Trigger the event
    io.nextFrame;
    io.release;
    root.draw();

    // Focus should be transferred once actions have been processed
    io.nextFrame;
    root.draw();

    assert(input.isFocused);

}
