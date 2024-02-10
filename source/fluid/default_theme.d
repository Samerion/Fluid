module fluid.default_theme;

import fluid.style;

/// Theme with no properties set.
///
/// Unlike `Theme.init` or `null`, which will be replaced by fluidDefaultTheme or the parent's theme, this can be used as
/// a valid theme for any node. This makes it useful for automatic tests, since it has guaranteed no margins, padding,
/// or other properties that may confuse the tester.
Theme nullTheme;

/// Default theme that Fluid will use if no theme is supplied. It is a very simple theme that does the minimum to make
/// the role of each node understandable.
Theme fluidDefaultTheme;

version (all)
static this() {

    import fluid.node;
    import fluid.frame;
    import fluid.button;
    import fluid.backend;
    import fluid.text_input;
    import fluid.scroll_input;

    with (Rule) {

        nullTheme.add(
            rule!Node(),
        );

        fluidDefaultTheme.add(
            rule!Node(
                textColor = color("#000"),
            ),
            rule!Frame(
                backgroundColor = color("#fff"),
            ),
            rule!Button(
                backgroundColor = color("#eee"),
                mouseCursor = FluidMouseCursor.pointer,
                margin.sideY = 2,
                padding.sideX = 6,

                when!"a.isHovered"(backgroundColor = color("#ccc")),
                when!"a.isFocused"(backgroundColor = color("#ddd")),  // TODO use an outline for focus
                when!"a.isPressed"(backgroundColor = color("#aaa")),
                when!"a.isDisabled"(
                    textColor = color("000a"),
                    backgroundColor = color("eee5"),
                    // TODO disabled should apply opacity, and should work for every node
                ),
            ),
            rule!TextInput(
                backgroundColor = color("#fffc"),
                borderStyle = colorBorder(color("#aaa")),
                mouseCursor = FluidMouseCursor.text,

                margin.sideY = 2,
                padding.sideX = 6,
                border.sideBottom = 2,

                when!"a.isEmpty"(textColor = color("000a")),
                when!"a.isFocused"(textColor = color("fff")),
                when!"a.isDisabled"(
                    textColor = color("000a"),
                    backgroundColor = color("fff5"),
                ),
            ),
            rule!ScrollInput(
                backgroundColor = color("aaa"),

                //backgroundStyleAdd.backgroundColor = color("eee"),
                when!"a.isHovered"(backgroundColor = color("888")),
                when!"a.isFocused"(backgroundColor = color("777")),
                when!"a.isPressed"(backgroundColor = color("555")),
                when!"a.isDisabled"(backgroundColor = color("aaa5")),
            ),
            //rule!FileInput.unselectedStyleAdd.backgroundColor = color("fff"),
            //rule!FileInput.selectedStyleAdd.backgroundColor = color("ff512f"),
        );

    }

}

// TODO remove
else
static this() {

    nullTheme = Theme.init.makeTheme!q{};

    fluidDefaultTheme = Theme.init.makeTheme!q{

        textColor = color("000");

        Frame.styleAdd!q{

            backgroundColor = color("fff");

        };

        Button!().styleAdd!q{

            backgroundColor = color("eee");
            mouseCursor = FluidMouseCursor.pointer;

            margin.sideY = 2;
            padding.sideX = 6;

            focusStyleAdd.backgroundColor = color("ddd");
            hoverStyleAdd.backgroundColor = color("ccc");
            pressStyleAdd.backgroundColor = color("aaa");
            disabledStyleAdd!q{

                textColor = color("000a");
                backgroundColor = color("eee5");

            };

        };

        TextInput.styleAdd!q{

            backgroundColor = color("fffc");
            borderStyle = colorBorder(color("aaa"));
            mouseCursor = FluidMouseCursor.text;

            margin.sideY = 2;
            padding.sideX = 6;
            border.sideBottom = 2;

            emptyStyleAdd.textColor = color("000a");
            focusStyleAdd.backgroundColor = color("fff");
            disabledStyleAdd!q{

                textColor = color("000a");
                backgroundColor = color("fff5");

            };

        };

        ScrollInput.styleAdd!q{

            backgroundColor = color("aaa");

            backgroundStyleAdd.backgroundColor = color("eee");
            hoverStyleAdd.backgroundColor = color("888");
            focusStyleAdd.backgroundColor = color("777");
            pressStyleAdd.backgroundColor = color("555");
            disabledStyleAdd.backgroundColor = color("aaa5");

        };

        FileInput.unselectedStyleAdd.backgroundColor = color("fff");
        FileInput.selectedStyleAdd.backgroundColor = color("ff512f");

    };


}
