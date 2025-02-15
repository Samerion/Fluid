module nodes.resolution_override;

import fluid;

@safe:

@("ResolutionOverride uses fixed size for its marginBox")
unittest {

    auto child = vspace(.layout!"fill");
    auto node = resolutionOverride(
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
