module glui.showcase.frames;

import glui;
import glui.showcase;


@safe:


Theme highlightBoxTheme;

static this() {

    highlightBoxTheme = makeTheme!q{
        border = 1;
        borderStyle = colorBorder(color!"#e62937");
    };

}

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
        ~ `forces the node to take over all of its available space. This is useful when you consider nodes that have `
        ~ `background, borders or are intended to store child nodes with their own layout — but we'll talk about it `
        ~ `later. For the purpose of this example, the box of each label node will be highlighted in red.`),
    () => highlightBoxTheme,
)
GluiSpace fillExample() {

    return vframe(
        .layout!"fill",
        label("Start-aligned node"),
        label(.layout!"fill", "Fill-aligned node"),
    );

}

@(
    () => label(.headingTheme, `Shrinking and expanding`),
    () => label(`You might have noticed something is off in the previous example. Despite the '.layout!"fill"' `
        ~ `option, the label did not expand to the end of the container, but only used up a single line. This has to `
        ~ `do with "expanding".`),
    // TODO
)
void endExample() { }
