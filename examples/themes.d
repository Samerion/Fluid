module fluid.showcase.themes;

import fluid;
import fluid.theme;
import fluid.showcase;


@safe:


@(
    () => label("While the default theme of Fluid is just enough to get started quickly, one will quickly realize "
        ~ "the importance styling has in creating legible and intuitive user interfaces. Let's start from the basics, "
        ~ "make some text red:"),
)
Label labelColorExample() {

    import fluid.theme;

    auto myTheme = Theme(
        rule!Label(
            textColor = color("#ff0000"),
        ),
    );

    return label(myTheme, "Hello, World!");

}

@(
    () => label("To define themes, the 'fluid.theme' module has to be imported. There's quite a few symbols it "
        ~ "comes with, so it's not imported by default. It's recommended not to import it globally, but only "
        ~ "within static constructors or relevant functions."),
)
void importExample() {

    import fluid;

    Theme makeTheme() {
        import fluid.theme;

        return Theme(
            rule!Label(
                textColor = color("#ff0000"),
            ),
        );
    }

}

@(
    () => label("A theme is defined by a set of rules. Each rule selects a set of nodes and applies styling "
        ~ "properties for them. 'rule!Label' defines style for Label, 'rule!Frame' defines style for Frame and "
        ~ "so on. 'textColor' is probably self-explanatory, it changes the color of the text drawn by the node."),
    () => label("color() creates a color given its hex code. If you're not familiar with hex codes, you can read "
        ~ "on it on MDN:"),
    () => button("<hex-color>", delegate { openURL("https://developer.mozilla.org/en-US/docs/Web/CSS/hex-color"); }),
)
Frame rulesExample() {

    auto theme = Theme(
        rule!Label(
            textColor = color("#f00"),
        ),
        rule!Button(
            textColor = color("#00f"),
        ),
    );

    return vframe(
        theme,
        label("Red text label"),
        button("Blue text button", delegate { }),
    );

}

@(
    () => label("Other than 'textColor', other properties can be adjusted, such as 'backgroundColor'."),
)
Frame backgroundColorExample() {

    auto theme = Theme(
        rule!Frame(
            // Black background
            backgroundColor = color("#000"),
        ),
        rule!Label(
            // White text
            textColor = color("#fff"),
        ),
    );

    return vframe(
        .layout!(1, "fill"),
        theme,
        label("Dark mode on."),
    );

}

@(
    () => label(.headingTheme, "Reacting to user input"),
    () => label("Nodes, especially input nodes, will change with the user input to provide feedback and guide "
        ~ "the user. You can set how this should look like using the 'when' rule. It accepts a predicate which "
        ~ "specifies *when* the rule should apply — and change its properties at runtime. The argument, 'a', "
        ~ "is the node that is being tested."),
)
Button whenExample() {

    auto theme = Theme(
        rule!Button(
            backgroundColor = color("#444444"),
            textColor = color("#ffffff"),

            when!"a.isHovered || a.isFocused"(
                backgroundColor = color("#2e956f")
            ),
            when!"a.isPressed"(
                backgroundColor = color("#35aa7f")
            ),
        ),
    );

    return button(theme, "Click me!", delegate { });

}

@(
    () => label("You can use the 'otherwise' method to branch out in case the predicate fails."),
)
Button otherwiseExample() {

    auto theme = Theme(
        rule!Button(
            textColor = color("#ffffff"),

            when!"a.isPressed"(
                backgroundColor = color("#35aa7f"),
            )
            .otherwise(
                backgroundColor = color("#444444"),
            ),
        ),
    );

    return button(theme, "Click me!", delegate { });

}

@(
    () => label(.headingTheme, "Copying and deriving themes"),
    () => label("In case you need to change some rules just for a portion of the tree, you can 'derive' themes from "
        ~ "others. To apply a theme, pass it to the constructor of the node. It will be passed down to its "
        ~ "children, unless one has its own theme specified:"),
)
Frame deriveExample() {

    auto theme = Theme(
        rule!Frame(
            backgroundColor = color("#000"),
        ),
        rule!Label(
            textColor = color("#fff"),
        ),
    );

    // Use `derive` to create a new version of the same theme
    auto blueTextTheme = theme.derive(
        rule!Label(
            textColor = color("#55b9ff"),
        ),
    );

    return vframe(
        .layout!(1, "fill"),
        theme,
        label("White text on black."),
        vspace(
            label("Themes apply recursively, and also apply to children nodes."),
            vspace(
                blueTextTheme,
                label("Unless the children have a different theme applied."),
            ),
        ),
    );

}

@(
    () => label(.headingTheme, "Tags"),
    () => label("If you need to make some nodes have a different look, perhaps because they serve a different "
        ~ "purpose or just need to stand out, you can use tags. If you're familiar with web development, tags are "
        ~ "very similar to CSS classes."),
    () => label("Tags have to be defined ahead of time. Create an enum to store your tags and mark it with "
        ~ "'@NodeTag'."),
)
Frame tagsExample() {

    @NodeTag
    enum Tags {
        green,
    }

    auto theme = Theme(
        rule!(Button, Tags.green)(
            backgroundColor = color("#009b00"),
        ),
    );

    return vframe(
        theme,
        button("Regular button", delegate { }),
        button(
            .tags!(Tags.green),
            "Green button",
            delegate { }
        ),
    );

}

@(
    () => label("The advantage tags have over buttons is that a single node can have multiple tags, which can be "
        ~ "mixed together. They also require less work if you need to add another tag, and do not apply recursively.")
)
Frame multipleTagsExample() {

    @NodeTag
    enum Tags {
        whiteLabel,
        greenButton,
    }

    auto theme = Theme(
        rule!(Label, Tags.whiteLabel)(
            textColor = color("#fff"),
        ),
        rule!(Button, Tags.greenButton)(
            backgroundColor = color("#009b00"),
        ),
    );

    return vframe(
        theme,
        button("Regular button", delegate { }),
        button(
            .tags!(Tags.greenButton, Tags.whiteLabel),
            "Green button with white text",
            delegate { }
        ),
    );

}
