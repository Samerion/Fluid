module fluid.showcase.drag_and_drop;

import fluid;
import fluid.showcase;


@safe:


Frame dragAndDropExample() {

    return vframe(
        .layout!"fill",

        vframe(
            .layout!(1, "fill"),
            dragSlot(label("World! ")),
            dragSlot(label("Goodbye, ")),
            dragSlot(label("Cruel ")),
        ),
        hseparator(),
        vframe(
            .layout!(1, "fill"),
            dragSlot(label("Hello, ")),
        ),
    );

}
