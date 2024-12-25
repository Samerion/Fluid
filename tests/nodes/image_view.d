module nodes.image_view;

import fluid;

@safe:

@("ImageView can load and display images")
unittest {

    auto image = generateColorImage(10, 10, color("#f00"));
    auto view = imageView(image);
    auto root = testSpace(view);

    root.drawAndAssert(
        view.drawsImage(image),
    );

}

@("ImageView uses specified size as minSize")
unittest {

    auto image = generateColorImage(10, 10, color("#f00"));
    auto view = imageView(image, Vector2(50, 50));
    auto root = testSpace(view);

    root.drawAndAssert(
        view.drawsImage(image).at(0, 0, 50, 50)
    );

}

@("ImageView can guess the size from Image")
unittest {

    auto image = generateColorImage(10, 10, color("#f00"));
    auto view = imageView(image);
    auto root = testSpace(view);

    root.drawAndAssert(
        view.drawsImage(image).at(0, 0, 10, 10)
    );

}

@("ImageView tries to fit the image into given area")
unittest {

    auto image = generateColorImage(10, 20, color("#f00"));
    auto view = imageView(
        .layout!(1, "fill"),
        image
    );
    auto root = sizeLock!testSpace(
        .sizeLimit(20, 20),
        view
    );

    // Fit into a square
    root.drawAndAssert(
        view.drawsImage(image).at(5, 0, 10, 20)
    );

    // Smaller square
    root.limit = sizeLimit(10, 10);
    root.updateSize();
    root.drawAndAssert(
        view.drawsImage(image).at(2.5, 0, 5, 10)
    );

    // Larger square
    root.limit = sizeLimit(40, 40);
    root.updateSize();
    root.drawAndAssert(
        view.drawsImage(image).at(10, 0, 20, 40)
    );

    // Wide rectangle
    root.limit = sizeLimit(40, 20);
    root.updateSize();
    root.drawAndAssert(
        view.drawsImage(image).at(15, 0, 10, 20)
    );

    // Tall rectangle
    root.limit = sizeLimit(20, 40);
    root.updateSize();
    root.drawAndAssert(
        view.drawsImage(image).at(0, 0, 20, 40)
    );

}

@("ImageView can load and draw images from files")
unittest {

    auto view = imageView("logo.png");
    auto stack = chain(
        fileChain(),
        arsdImageChain(),
        view,
    );
    auto root = testSpace(stack);

    root.draw();
    root.drawAndAssert(
        view.drawsImage(view.image),
    );

    // logo.png parameters
    assert(view.image.width == 998);
    assert(view.image.height == 480);

}
