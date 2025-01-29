module nodes.hover_transform;

import fluid;

@safe:

@("HoverTransform yields transformed pointers when iterated")
unittest {

    auto transform = hoverTransform(Rectangle(50, 50, 100, 100));
    auto hover = hoverChain(
        .layout!(1, "fill"),
        transform,
    );
    auto root = sizeLock!testSpace(
        .sizeLimit(500, 500),
        hover
    );

    root.draw();

    auto action = hover.point(50, 50);
    foreach (HoverPointer pointer; transform) {
        assert(pointer.position == Vector2(0, 0));
        assert(pointer.scroll == Vector2(0, 0));
    }

    action.move(75, 150).scroll(10, 20);
    foreach (HoverPointer pointer; transform) {
        assert(pointer.position == Vector2(125, 500));
        assert(pointer.scroll == Vector2(10, 20));
    }

    hover.point(0, 0);
    auto index = 0;
    foreach (HoverPointer pointer; transform) {
        if (index++ == 0) {
            assert(pointer.position == Vector2(125, 500));
            assert(pointer.scroll == Vector2(10, 20));
        }
        else {
            assert(pointer.position == Vector2(-250, -250));
            assert(pointer.scroll == Vector2(0, 0));
        }
    }

}
