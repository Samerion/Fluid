// This module is not currently present in the example list.
// TODO
module fluid.tour.popups;

import fluid;
import fluid.tour;


@safe:

Space popupExample() {

    Space root;

    return root = vspace(
        popupButton(
            "Click me!",
            label("Text"),
            button("btn1", delegate { }),
            button("btn2", delegate { }),
            button("btn3", delegate { }),
            popupButton(
                "Click me too!",
                button("btn4", delegate { }),
                button("btn5", delegate { }),
                button("btn6", delegate { }),
                popupButton(
                    "Third",
                    label("Woo!"),
                ),
            ),
        ),
    );

}
