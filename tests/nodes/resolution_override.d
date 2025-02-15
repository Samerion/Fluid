module nodes.resolution_override;

import fluid;

@safe:

@("ResolutionOverride uses fixed size for its marginBox")
unittest {

    auto child = vspace(
        .layout!(1, "fill")
    );
    auto node = resolutionOverride!vspace(
        Vector2(1920, 1080),
        child,
    );
    auto root = sizeLock!testSpace(
        .nullTheme,
        .sizeLimit(600, 600),
        node
    );

    root.drawAndAssert(
        node.isDrawn().at(0, 0, 600, 1080),
        child.isDrawn().at(0, 0, 1920, 1080),
    );
    assert(node.paddingBoxForSpace(Rectangle(0, 0, 800, 600)) == Rectangle(0, 0, 1920, 1080));

}

@("ResolutionOverride sets its own DPI")
unittest {

    auto contentInner = label("Hello");
    auto contentOuter = label("Hello");
    auto node = resolutionOverride!vspace(
        .layout!"fill",
        Vector2(100, 100),
        contentInner,
    );
    auto root = testSpace(
        .nullTheme,
        node,
        contentOuter,
    );
    root.dpi = Vector2(120, 120);

    root.drawAndAssert(
        node.isDrawn().at(0, 0, 80, 80),
    );

    assert(contentInner.text.texture.dpi == Vector2(96, 96));
    assert(contentOuter.text.texture.dpi == Vector2(120, 120));

}
