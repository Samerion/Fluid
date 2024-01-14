module glui.showcase.frames;

import glui;
import glui.showcase;


@safe:


@(
    () => label("Every Glui node can provide hints on how it should be laid out by the node its inside of, its parent. "
        ~ "These are provided by passing the '.layout' setting as the first argument to the node."),
    () => label("One of the parameters controlled with this setting is a node's align. Each node is virtually wrapped "
        ~ "in a box that restricts its boundaries. If a node is given more space than it needs, it will be aligned "
        ~ "differently within its boundary box based on this parameter. By default, alignment is set to the top-left "
        ~ `corner, which is equivalent to setting '.layout!("start", "start")'. `),
)
GluiLabel startLayoutExample() {

    return label(
        .layout!("start", "start"),
        "Default alignment"
    );

}

@(
    () => label(`As you can see, the option above does nothing, but each of the two "start" values can be replaced `
        ~ `with "center", "end" or "fill". "start" corresponds to the left or top side of the available space box, `
        ~ `while "end" corresponds to the right or bottom side. "center", as you might guess, aligns a node to the `
        ~ `center.`),
)
GluiLabel centerLayoutExample() {

    return label(
        .layout!("center", "start"),
        "Aligned to the center",
    );

}

@(
    () => label("Layout accepts two separate align values because they correspond to horizontal and vertical axis "
        ~ "separately. Because it's really common to set them both to the same value, for example to fully center a "
        ~ "node, it's possible to take a shortcut and specify just one."),
)
GluiLabel symmetricalLayoutExample() {

    return label(
        .layout!"center",
        "Aligned to the middle",
    );

}

@(
    () => label(`You might be curious about the "fill" option now. This one, instead of changing the node's alignment, `
        ~ `forces the node to take over all of its available space.`),
)
void endExample() { }
