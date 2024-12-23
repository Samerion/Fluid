module nodes.onion_frame;

import fluid;

@safe:
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
    auto root = testSpace(frame);

    with (Rule)
    root.theme = nullTheme.derive(
        rule!Label(textColor = color!"000"),
    );

    root.draw();
    root.drawAndAssert(
        // TODO view.drawsImage
        labels[0].drawsHintedImage(labels[0].text.texture.chunks[0].image).at(0, 0),
        labels[1].drawsHintedImage(labels[1].text.texture.chunks[0].image),
    );

}
