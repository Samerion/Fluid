module nodes.label;

import fluid;

@safe:

@("Label draws text, and updates it if written to")
unittest {

    import fluid.theme;

    auto root = label("Hello, World!");
    auto test = testSpace(root);

    test.theme = nullTheme.derive(
        rule!Label(textColor = color!"000"),
    );

    test.draw();
    test.drawAndAssert(
        root.drawsImage(root.text.texture.chunks[0].image).at(0, 0)
    );

    const initialTextArea = root.text.size.x * root.text.size.y;

    // io.assertTexture(root.text.texture.chunks[0], Vector2(0, 0), color!"fff");
    // io.nextFrame;

    root.text ~= " It's a nice day today!";
    root.draw();

    // io.assertTexture(root.text.texture.chunks[0], Vector2(0, 0), color!"fff");

    const newTextArea = root.text.size.x * root.text.size.y;

    assert(newTextArea > initialTextArea);

}
