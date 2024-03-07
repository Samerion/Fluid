module fluid.showcase.frames;

import fluid;
import fluid.showcase;


@safe:


// Start article

@(
    () => label("Every Fluid node can provide hints on how it should be laid out by the node its inside of, its "
        ~ "parent. These are provided by passing the '.layout' setting as the first argument to the node."),
    () => label("One of the parameters controlled with this setting is a node's align. Each node is virtually wrapped "
        ~ "in a box that restricts its boundaries. If a node is given more space than it needs, it will be aligned "
        ~ "differently within its boundary box based on this parameter. By default, alignment is set to the top-left "
        ~ `corner, which is equivalent to setting '.layout!("start", "start")'. `),
)
Label startLayoutExample() {

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
Label centerLayoutExample() {

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
Label symmetricalLayoutExample() {

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
Frame fillExample() {

    return vframe(
        .layout!"fill",
        label("Start-aligned node"),
        label(.layout!"fill", "Fill-aligned node"),
    );

}


// Heading: Shrinking and expanding


@(
    () => label(.tags!(Tags.heading), `Shrinking and expanding`),
    () => label(`You might have noticed something is off in the previous example. Despite the '.layout!"fill"' `
        ~ `option, the label did not expand to the end of the container, but only used up a single line. This has to `
        ~ `do with "expanding".`),
    () => label(`By default, nodes operate in "shrink mode," which means they will only take the space they need. `
        ~ `The parent node may have spare space to give, which means the node has to decide what part of that space it `
        ~ `has to take. This is what happens when you change alignment: A start aligned node will take the top-left `
        ~ `corner of that space, while an end aligned node will take the bottom-right corner, but they cannot move `
        ~ `within space that hasn't been explicitly assigned to them.`),
    () => label(`Because the job of frames is to align multiple nodes in a single row or column, frames will give `
        ~ `their children space within a column or row according to their need. The nodes are given maximum space on `
        ~ `the other axis, however, because it's not shared with any other node.`),
    () => label(`This is where the 'expand' layout setting is useful. The frame will evenly distribute space among `
        ~ `expanding nodes.`),
    () => highlightBoxTheme,
)
Frame expandExample() {

    return vframe(
        .layout!"fill",
        label(.layout!1, "Start-aligned node"),
        label(.layout!(1, "fill"), "Fill-aligned node"),
        label(.layout!(1, "center"), "Center-aligned node"),
    );

}

@(
    () => label(`See? The nodes have been assigned equal heights. They occupy the same amount of space within the `
        ~ `column. Each uses a different part of the space they have been assigned because of differences in alignment `
        ~ `of each.`),
    () => label(`Note that expanding is defined as a number. Let's see what happens if we change the number.`),
    () => highlightBoxTheme,
)
Frame expandSegmentExample() {

    return vframe(
        .layout!"fill",
        label(.layout!(1, "fill"), "Expand: 1"),
        label(.layout!(2, "fill"), "Expand: 2"),
        label(.layout!(3, "fill"), "Expand: 3"),
    );

}

@(
    () => label(`The space of the frame has been distributed fully between the labels, but each took a different `
        ~ `fraction. This is exactly why expanding is a number: The first label took one piece of the space, the second `
        ~ `took two, and the last took three. It defines a fraction, where the specified number is the numerator. The `
        ~ `denominator is the sum of all expand settings — in this case that's 6. Which means, each node takes 1/6, `
        ~ `2/6 and 3/6 of the space respectively.`),
    () => label(`Note: Setting expand to 0 effectively disables expand and makes the node shrink. In this case, the `
        ~ `expand argument can be omitted.`),
    () => label(`Shrinking and expanding nodes can be used alongside in the same frame:`),
    () => highlightBoxTheme,
)
Frame shrinkNExpandExample() {

    return vframe(
        .layout!"fill",
        label(.layout!(0, "fill"), "Shrink"),
        label(.layout!(1, "fill"), "Expand"),
    );

}


// Heading


@(
    () => label(.tags!(Tags.heading), "Practical examples"),
    () => label(`Mixing shrinking and expanding nodes in the same frame is very useful. Consider implementing two `
        ~ `buttons for switching pages, just like at the end of the page. The "back" button on the left side, the `
        ~ `"right" button on the right.`),
)
Frame switchPagesExample() {

    return hframe(
        .layout!("fill", "center"),
        label("Previous page"),
        label(.layout!(1, "end"), "Next page"),
    );

}

@(
    () => label("Of course, the labels above are not functional as buttons. Buttons will be covered in a separate "
        ~ "chapter."),
    () => label("To make the example more complex, let's try creating a more complete pagination panel, with two "
        ~ "buttons like above, and a few buttons in the center to jump to a specific page."),
)
Frame paginationExample() {

    return hframe(
        .layout!("fill", "center"),
        label(.layout!(1, "start"), "Previous page"),
        hframe(
            label(" 1 "),
            label(" 2 "),
            label(" 3 "),
        ),
        label(.layout!(1, "end"), "Next page"),
    );

}
