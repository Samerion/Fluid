// This module is not currently present in the example list.
// TODO
module fluid.showcase.popups;

import fluid;
import fluid.showcase;


@safe:
version (none):


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
            ),
        ),
        button("Pick a file", delegate {
            root.tree.spawnPopup(
                fileInput("Open a file", delegate { })
            );
        }),
    );

}
