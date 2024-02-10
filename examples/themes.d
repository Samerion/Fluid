module fluid.showcase.themes;

import fluid;
import fluid.showcase;


@safe:


@(
    () => label(.layout!"fill", .warningTheme, "Warning: Themes will be completely reworked in 0.7.0. None of the code "
        ~ "in this article is guaranteed to work in the future. Themes are currently also far more complex than they "
        ~ "need to be — prepare for a ride."),
    () => label("One won't get far with Fluid without changing the theme of their app. While the default theme is "
        ~ "enough just to get started, one will quickly realize styling is crucial in creating legible and "
        ~ "understandable user interfaces. Let's start from the basics:"),
)
Frame themeExample() {

    // Create a theme using makeTheme and specify rules for each node
    auto theme = makeTheme!q{

        // Give frames a dark-colored background
        // We're using CSS hex codes to specify colors
        Frame.styleAdd!q{
            backgroundColor = color!"#1c1c1c";
        };

        // Make text white to make it readable
        Label.styleAdd!q{
            textColor = color!"#fff";
        };

    };

    return vframe(
        .layout!"fill",
        theme,  // <- Pass the theme as an argument
        label("This text will display on a dark background."),
    );

}

@(
    () => label("There might be a quite a lot happening in the example above. Let's unpack:"),
    () => hspace(label("— "), label("'makeTheme' will produce a new theme which you can later use in your app. Themes "
        ~ "are constructed from rules which you define inside the q{ } blocks.")),
    () => hspace(label("— "),
        vspace(
            label("We define two rules, one for frames and one for labels. We change their "
                ~ "colors, which should probably be fairly easy to understand. For reference on CSS hex colors, see "),
            button("MDN <hex-color>", delegate {
                openURL(`https://developer.mozilla.org/en-US/docs/Web/CSS/hex-color`);
            })
        )),
    () => hspace(label("— "), label("Finally, we pass the theme next to the layout argument of the frame. It's "
        ~ "important that the layout and theme arguments, if either or both are present, must be the first "
        ~ "arguments.")),
    () => label("Nodes will automatically inherit themes from their parents, until they have another theme assigned."),
)
Frame twoThemesExample() {

    auto theme = makeTheme!q{

        // For single properties, we can use the shorthand syntax
        Frame.styleAdd.backgroundColor = color!"#54b8ff";

    };

    auto otherTheme = makeTheme!q{
        Label.styleAdd!q{
            backgroundColor = color!"#751fbe";
            textColor = color!"#fff";
        };
    };

    return vframe(
        .layout!"fill",
        theme,
        label(
            .layout!(1, "fill"),
            "First theme"
        ),
        label(
            .layout!(1, "fill"),
            otherTheme,
            "Second theme!"
        ),
    );

}

@(
    () => label("Some components, like buttons, can have multiple styles, which they switch between based on their "
        ~ "state. You can define a different style for a button that is hovered, held down, or focused (relevant if "
        ~ "using a keyboard)."),
)
Button buttonExample() {

    auto myTheme = makeTheme!q{
        Button.styleAdd!q{
            // Light grey by default
            backgroundColor = color!"#ddd";

            // Light grey when hovered, light blue when focused, grey when pressed
            hoverStyleAdd.backgroundColor = color!"#bbb";
            focusStyleAdd.backgroundColor = color!"#9aedf4";
            pressStyleAdd.backgroundColor = color!"#444";
        };
    };

    return button(myTheme, "Play with me!", delegate { });

}

@(
    () => label("You can change the font used on labels or buttons using 'Style.loadTypeface'."),
)
Frame typefaceExample() {

    auto myTheme = makeTheme!q{

        // Load typeface from given file at 14pts
        Label.styleAdd!q{
            import std.file, std.path;
            auto fontPath = thisExePath.dirName.buildPath("../examples/ibm-plex-mono.ttf");
            typeface = Style.loadTypeface(fontPath, 14);
        };

    };

    return vframe(
        label("Default font"),
        label(myTheme, "Custom font"),
    );

}

@(
    () => label(.headingTheme, "Padding, margin and borders"),
    () => label("To make the UI less cluttered, it's a good idea give it some space. You can utilize padding and "
        ~ "margin for this purpose. Both have the same meaning in Fluid as they have in HTML/CSS, if you're familiar "
        ~ "with web development."),
    () => label("Both serve a similar purpose, but apply to a different part of the node: Padding is present on the "
        ~ "interior, margin, on the exterior. This is visible "
        ~ "when paired with background or borders. Padding will increase space covered by the background, whereas "
        ~ "margin will display completely outside of the node. Let's start by exemplifying usage of padding:"),
    () => label("Note: It's not possible to change padding or margin using state-based styles, like the ones you can "
        ~ "use on a button."),
)
Frame paddingExample() {

    auto myTheme = makeTheme!q{

        Label.styleAdd!q{
            padding = 10;
            margin = 20;
            backgroundColor = color!"#54b8ff";
        };

    };

    return vframe(
        label("Default settings"),
        label(myTheme, "Newly created theme with padding added"),
    );

}

@(
    () => label("You can also add borders to nodes. Borders are defined by two properties, 'border' and 'borderStyle'. "
        ~ "The former is familiar, because it works exactly the same as margin and padding — you can adjust border "
        ~ "width separately for each side. The latter defines how exactly should the border be displayed. You can "
        ~ "easily create a simple colored border:"),
    () => label("Note: It's not possible to change border width using state-based styles, like the ones you can "
        ~ "use on a button."),
)
Frame borderExample() {

    auto myTheme = makeTheme!q{
        Frame.styleAdd!q{
            backgroundColor = color!"#54b8ff";
            padding = 6;
            margin = 4;
            border = 2;
            borderStyle = colorBorder(color!"#1e425a");
        };
    };

    return vframe(
        myTheme,
        label("This frame has border!"),
    );

}

@(
    () => label("All of the properties; padding, margin and border, can be specified separately for each side. "
        ~ "Assigning them directly, like above, makes them equal on every side."),
)
void sideArrayExample() {

    auto myTheme = makeTheme!q{

        // Assign all sides
        padding = 4;

        // Assign each side individually
        // Values are ordered by axis
        // In order: Left, right, top, bottom
        padding = [2, 4, 6, 8];

        // The above is equivalent to the more verbose form:
        padding.sideLeft = 2;
        padding.sideRight = 4;
        padding.sideTop = 6;
        padding.sideBottom = 8;

        // You can also assign both values on the axis at a time
        padding.sideX = 4;  // left and right
        padding.sideY = 8;  // top and bottom

        // All of the same rules apply also for margin and border
        border = [4, 4, 6, 6];
        padding.sideX = 6;

    };

}

@(
    () => label("Border color can also be defined separately for each side. This might be great if you like "
        ~ "retro-looking buttons.")
)
Button fancyButtonExample() {

    auto myTheme = makeTheme!q{
        Button.styleAdd!q{
            auto start = color!"#fff";
            auto end = color!"#666";
            borderStyle = colorBorder([start, end, start, end]);
            border = 3;
            padding = 4;

            // Make it inset when pressed
            hoverStyleAdd;
            focusStyleAdd.backgroundColor = color!"#b1c6e4";
            pressStyleAdd.backgroundColor = color!"#aaa";
            pressStyleAdd.borderStyle = colorBorder([end, start, end, start]);
        };
    };

    return button(myTheme, "Fancy button!", delegate { });

}

@(
    () => label(.headingTheme, "Spaces"),
    () => label("Frames are versatile. They can be used to group nodes, configure their layout, but also to set a "
        ~ "common background or to add extra margin around a set of nodes. Frames, by grouping a number of related "
        ~ "items can also form an important semantic role. However, often it's useful to insert a frame "
        ~ "just to reconfigure the layout."),
    () => label("Once you go through the step of styling a frame — adding background, margin, padding, or border, "
        ~ "every other frame sharing the same theme will have the same style. For cases where you don't want any of "
        ~ "that fanciness, you could work with a secondary theme, but there's an easier way through. Instead of using "
        ~ "a frame node, there exists a dedicated node for the purpose — a Space."),
    () => label("Spaces and frames share all the traits except for one. They cannot have background or border. It's "
        ~ "a small difference in the long run, but it establishes Space as the minimal and more "
        ~ "layout-oriented 'helper' node."),
    () => label("Usage is identical, just use 'vspace' and 'hspace'. In object-oriented programming terms, frames "
        ~ "are subclasses of spaces, which means any frame will fit where a space will."),
)
Space spaceExample() {

    auto myTheme = makeTheme!q{
        Frame.styleAdd!q{
            border = 1;
            borderStyle = colorBorder(color!"#000");
        };
    };

    return vspace(
        myTheme,
        hframe(
            label(.layout!1, "Text inside of a frame. This frame is surrounded by a border."),
            button("Decorative button", delegate { }),
        ),
        hspace(
            label(.layout!1, "Text inside of a space. It's as plain as it can be."),
            button("Decorative button", delegate { }),
        ),
    );

}

@(

    () => label(.headingTheme, "Extras"),
    () => label("The 'tint' property can be used to change the color of a node as a whole, including its content. "
        ~ "Moreover, the 'opacity' property functions as a shortcut for changing only the alpha channel, making it "
        ~ "easy to create half-transparent nodes."),
)
Space opacityExample() {

    auto opaque = makeTheme!q{
        Frame.styleAdd!q{
            backgroundColor = color!"#e65bb8";
            borderStyle = colorBorder(color!"#751fbe");
            border = 2;
            padding = 6;
        };
    };

    // New theme, inherit properties from opaque
    auto halfOpaque = opaque.makeTheme!q{
        Frame.styleAdd.opacity = 0.5;
    };

    auto transparent = opaque.makeTheme!q{
        Frame.styleAdd.opacity = 0;
    };

    auto dark = opaque.makeTheme!q{
        Frame.styleAdd.tint = color!"#444";
    };

    return vspace(

        vframe(
            opaque,
            label("Hello, world!"),
        ),
        vframe(
            halfOpaque,
            label("Fading..."),
            vframe(
                dark,
                label("Fading into darkness..."),
            ),
        ),
        vframe(
            dark,
            label("Hello, darkness."),
        ),
        vframe(
            transparent,
            label("Can't see me!"),
        ),

    );

}
