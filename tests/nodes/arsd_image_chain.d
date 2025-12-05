module nodes.arsd_image_chain;

import fluid;

@safe:

@("ARSDImageChain can decode PNGs")
unittest {

    auto imageLoader = arsdImageChain();
    auto fileLoader = fileChain();

    const file = fileLoader.loadFile("logo.png");
    const image = imageLoader.loadImage(file);

    assert(image.format == Image.Format.rgba);
    assert(image.width == 998);
    assert(image.height == 480);

}
