module fluid.showcase.forms;

import fluid;
import fluid.showcase;


@safe:


Space myExample() {

    auto group = new RadioboxGroup;

    return vspace(
        fieldSlot!vframe(
            label("Username"),
            textInput(),
        ),

        fieldSlot!hframe(
            checkbox(),
            label("Accept my rules"),
        ),
        fieldSlot!hframe(
            checkbox(),
            label("Accept spam"),
        ),

        fieldSlot!hframe(
            radiobox(group),
            label("Gender"),
        ),
        fieldSlot!hframe(
            radiobox(group),
            label("Very gender"),
        ),
    );

}
