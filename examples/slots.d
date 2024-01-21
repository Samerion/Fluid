module fluid.showcase.slots;

import fluid;
import fluid.showcase;


@safe:


@(
    () => label("If you need to swap a node for another during runtime, there is a very helpful node just to do the "
        ~ "job. Node slots are functionally placeholders for any other node. You can change what node it holds at any "
        ~ "time, and you can leave it empty."),
)
Frame slotExample() {

    auto mySlot = nodeSlot!Label();

    return vframe(
        mySlot = label("Click the button below!"),
        button("Replace the slot", delegate {
            mySlot = label("Content replaced!");
        })
    );

}

@(
    () => label("Node slots are templates — You can define what type of nodes they're allowed to hold. In the example "
        ~ "above, the node slot is initalized with 'nodeSlot!Label()' which means it will only take in labels. Thanks "
        ~ "to this, we can easily peek inside or change its contents:"),
)
Frame secondExample() {

    auto mySlot = nodeSlot!Label();

    return vframe(
        mySlot = label("Hello, World!"),
        button("Replace the slot", delegate {
            mySlot.value.text = "Content replaced!";
        })
    );

}

@(
    () => label("Node slots can be emptied using the 'clear()' method:"),
)
Frame clearExample() {

    auto mySlot = nodeSlot!Label();
    auto myLabel = label("This label is in a node slot");

    return vframe(
        mySlot = myLabel,
        button("Remove the label", delegate {
            mySlot.clear();
        }),
        button("Put the label back", delegate {
            mySlot = myLabel;
        }),
    );

}

@(
    () => label("Note that node slots are also affected by frame layout rules. Because the slot is separate from the "
        ~ "node it holds, you need to set 'expand' on the slot, and if you do, make it 'fill' aligned. You don't need "
        ~ "to do the latter if you set alignment on the slot itself."),
    () => highlightBoxTheme,
)
Frame slotLayoutExample() {

    return vframe(
        .layout!"fill",
        nodeSlot!Label(
            .layout!(1, "fill"),
            label(.layout!"center", "Centered (through label)")
        ),
        nodeSlot!Label(
            .layout!(1, "fill"),
            label(.layout!"fill", "Filled")
        ),
        nodeSlot!Label(
            .layout!(1, "center"),
            label("Centered (through slot)")
        ),
    );

}
