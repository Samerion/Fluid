module fluid.showcase.forms;

import fluid;
import fluid.showcase;


@safe:


Space myExample() {

    return vspace(
        fieldSlot!vframe(
            label("Username"),
            textInput("Password"),
        ),
    );

}
