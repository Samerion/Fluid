module glui.showcase.basics;

import glui;


@safe:


@(() => label("To start from the basics, user interfaces in Glui are built using Nodes. There's a number of different "
    ~ "node types; Each serves a different purpose and does something different. A good initial example is the "
    ~ "label node, which can be used to display text. Let's recreate the classic Hello World program."))
GluiNode helloWorldExample() {

    return label("Hello, World!");

}
