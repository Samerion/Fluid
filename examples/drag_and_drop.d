// This example is excluded from the showcase for now.
// TODO
module fluid.showcase.drag_and_drop;

import fluid;
import fluid.showcase;


@safe:


Frame dragAndDropExample() {

    return vframe(
        .layout!"fill",

        hframe(
            .layout!(1, "fill"),
            .acceptDrop,
            dragSlot(label("Hello,")),
            dragSlot(label("Goodbye,")),
        ),
        hseparator(),
        hframe(
            .layout!(1, "fill"),
            .acceptDrop,
            dragSlot(label("Fluid!")),
            dragSlot(label("World!")),
            dragSlot(label("Cruel")),
        ),
    );

}

Frame dropMapExample() {

    return vframe(
        .layout!"fill",

        mapFrame(
            .layout!(1, "fill"),
            .acceptDrop,
            dragSlot(label("Hello,")),
            dragSlot(label("Goodbye,")),
        ),
        hseparator(),
        mapFrame(
            .layout!(1, "fill"),
            .acceptDrop,
            dragSlot(label("Fluid!")),
            dragSlot(label("World!")),
            dragSlot(label("Cruel")),
        ),
    );

}
