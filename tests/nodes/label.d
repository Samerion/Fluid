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

    const initialTextArea = root.text.size.x * root.text.size.y;
    auto firstImage = root.text.texture.chunks[0].image;
    
    test.drawAndAssert(
        root.drawsHintedImage(firstImage).at(0, 0)
    );

    root.text ~= " It's a nice day today!";
    root.draw();

    const newTextArea = root.text.size.x * root.text.size.y;
    auto secondImage = root.text.texture.chunks[0].image;

    test.drawAndAssert(
        root.drawsHintedImage(secondImage).at(0, 0)
    );

    assert(firstImage != secondImage);
    assert(newTextArea > initialTextArea);

}
