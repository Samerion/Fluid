module fluid.showcase.drag_and_drop;

import fluid;
import fluid.showcase;


@safe:


Frame dragAndDropExample() {

    return vframe(
        .layout!"fill",

        hframe(
            .layout!(1, "start", "fill"),
            .canDrop,
            dragSlot(label("World! ")),
            dragSlot(label("Goodbye, ")),
        ),
        hseparator(),
        hframe(
            .layout!(1, "end", "fill"),
            .canDrop,
            dragSlot(label("Hello, ")),
            dragSlot(label("Cruel ")),
            dragSlot(label("a\nb\nc")),
        ),
    );

}
