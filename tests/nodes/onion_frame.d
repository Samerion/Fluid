module nodes.onion_frame;

import fluid;

@safe:

@("OnionFrame draws background")
unittest {

    auto frame = sizeLock!onionFrame(
        .sizeLimit(400, 400),
        nullTheme.derive(
            rule!OnionFrame(
                Rule.backgroundColor = color("#f00"),
            ),
        ),
    );
    auto root = testSpace(frame);

    root.drawAndAssert(
        frame.drawsRectangle(0, 0, 400, 400).ofColor("#f00"),
    );
}

@("OnionFrame will display nodes on top of each other")
unittest {

    ImageView view;
    Label[2] labels;

    auto frame = onionFrame(

        view = imageView("logo.png"),

        labels[0] = label(
            "Hello, Fluid!"
        ),

        labels[1] = label(
            layout!(1, "center"),
            "Hello, Fluid! This text should fit the image."
        ),

    );
    auto root = testSpace(
        chain(fileChain(), arsdImageChain(), frame)
    );

    with (Rule)
    root.theme = nullTheme.derive(
        rule!Label(textColor = color!"000"),
    );

    root.draw();
    root.drawAndAssert(
        view.drawsImage(view.image),
        labels[0].drawsHintedImage(labels[0].text.texture.chunks[0].image).at(0, 0),
        labels[1].drawsHintedImage(labels[1].text.texture.chunks[0].image),
    );

}
