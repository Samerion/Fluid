module nodes.label;

import fluid;

@safe:

@("Label draws text, and updates it if written to")
unittest {

    import fluid.theme;

    auto node = label("Hello, World!");
    auto root = testSpace(node);

    root.theme = nullTheme.derive(
        rule!Label(textColor = color!"000"),
    );

    root.draw();

    const initialTextArea = node.text.size.x * node.text.size.y;
    auto firstImage = node.text.texture.chunks[0].image;

    root.drawAndAssert(
        node.drawsHintedImage(firstImage).at(0, 0)
    );

    node.text ~= " It's a nice day today!";
    root.draw();

    const newTextArea = node.text.size.x * node.text.size.y;
    auto secondImage = node.text.texture.chunks[0].image;

    root.drawAndAssert(
        node.drawsHintedImage(secondImage).at(0, 0).withPalette(color("#000"))
    );

    assert(firstImage != secondImage);
    assert(newTextArea > initialTextArea);

}

@("Text is correctly drawn in different DPI settings")
unittest {

    auto content = label("Hello, World!");
    auto root = testSpace(.nullTheme, content);

    root.drawAndAssert(
        content.drawsHintedImage().at(0, 0, 109, 27).ofColor("#ffffff")
            .sha256("e5b75b97f0894aeba0c17c078a7509ab0e9e652b89797817fac0063cc82055f4"),
    );

    // TODO affected by https://git.samerion.com/Samerion/Fluid/issues/330
    root.dpi = Vector2(120, 120);
    root.drawAndAssert(
        content.drawsHintedImage().at(0, 0, 107.2, 26.4).ofColor("#ffffff")
            .sha256("700fa10edb2d15dd74b4232c0ff479ab8a0a099240f7597481365ec242c2229a"),
    );

}
