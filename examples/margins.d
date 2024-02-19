module fluid.showcase.margins;

import fluid;


@safe:


@NodeTag
enum BoxTags {
    margin,
    border,
    padding,
    content,
}

Theme boxTheme;

static this() {

    import fluid.theme;

    boxTheme = Theme(
        rule!Frame(
            margin = 0,
            margin.sideBottom = 18,
            padding.sideY = 2,
            padding.sideX = 18,
            border = 1,
            borderStyle = colorBorder(color("#0005")),
        ),
        rule!(Frame, BoxTags.margin)(
            backgroundColor = color("#ff8a5c"),
        ),
        rule!(Frame, BoxTags.border)(
            backgroundColor = color("#ffb35d"),
        ),
        rule!(Frame, BoxTags.padding)(
            backgroundColor = color("#f7ff5e"),
        ),
        rule!(Frame, BoxTags.content)(
            backgroundColor = color("#61ff66"),
        ),
        rule!Label(
            typeface = Style.loadTypeface(10),  // default typeface at size 10
            margin = 0,
            padding = 0,
        ),
    );

}


@(
    () => label("When it comes to margins, Fluid uses a model that is very similar, or even identical, to "
        ~ `HTML. Each node is composed of a few "boxes", stacked one within each other. From the core, `
        ~ "the content box holds text, images, other nodes. Padding adds some space for that content to "
        ~ "breathe, border is used to add an outline around the node, and margin defines the outer spacing."),
    () => vframe(
        .layout!"center",
        .boxTheme,
        .tags!(BoxTags.margin),
        label(.layout!"center", "Margin"),
        vframe(
            .tags!(BoxTags.border),
            label(.layout!"center", "Border"),
            vframe(
                .tags!(BoxTags.padding),
                label(.layout!"center", "Padding"),
                vframe(
                    .tags!(BoxTags.content),
                    label(.layout!"center", "Content"),
                )
            )
        )
    ),
    () => label("If you add background to a node, it will be displayed behind the border box. In fact, "
        ~ "backgrounds and borders are drawn during the same step."),
    () => label("Let's start by making a node with nothing but border."),
)
Label labelColorExample() {

    // TODO
    // This example should have the user manipulate the values themselves

    import fluid.theme;

    auto myTheme = Theme(
        rule!Label(
            textColor = color("#ff0000"),
        ),
    );

    return label(myTheme, "Hello, World!");
}
