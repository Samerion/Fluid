module legacy.onion_frame;

import fluid;

@safe:

@("[TODO] Legacy: OnionFrame will display nodes on top of each other")
unittest {

    ImageView view;
    Label[2] labels;

    auto io = new HeadlessBackend(Vector2(1000, 1000));
    auto root = onionFrame(

        view = imageView("logo.png"),

        labels[0] = label(
            "Hello, Fluid!"
        ),

        labels[1] = label(
            layout!(1, "center"),
            "Hello, Fluid! This text should fit the image."
        ),

    );

    with (Rule)
    root.theme = nullTheme.derive(
        rule!Label(textColor = color!"000"),
    );
    root.io = io;
    root.draw();

    // imageView
    io.assertTexture(view.texture, Vector2(0, 0), color!"fff");

    // First label
    io.assertTexture(labels[0].text.texture.chunks[0], Vector2(0, 0), color("#fff"));

    // TODO onionFrame should perform shrink-expand ordering similarly to `space`. The last label should wrap.

}
