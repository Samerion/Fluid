module legacy.image_view;

import fluid;

@safe:

@("[TODO] Legacy: ImageView draws images")
@system unittest {

    // TODO test for keeping aspect ratio
    auto io = new HeadlessBackend(Vector2(1000, 1000));
    auto root = imageView(.nullTheme, "logo.png");

    // The texture will lazy-load
    assert(root.texture == Texture.init);

    root.io = io;
    root.draw();

    // Texture should be loaded by now
    assert(root.texture != Texture.init);

    io.assertTexture(root.texture, Vector2(0, 0), color!"fff");

}

