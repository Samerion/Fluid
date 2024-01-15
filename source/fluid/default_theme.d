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

static this() {

    nullTheme = Theme.init.makeTheme!q{};

    fluidDefaultTheme = Theme.init.makeTheme!q{

        textColor = color("000");

        FluidFrame.styleAdd!q{

            backgroundColor = color("fff");

        };

        FluidButton!().styleAdd!q{

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

        FluidTextInput.styleAdd!q{

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

        FluidScrollInput.styleAdd!q{

            backgroundColor = color("aaa");

            backgroundStyleAdd.backgroundColor = color("eee");
            hoverStyleAdd.backgroundColor = color("888");
            focusStyleAdd.backgroundColor = color("777");
            pressStyleAdd.backgroundColor = color("555");
            disabledStyleAdd.backgroundColor = color("aaa5");

        };

        FluidFileInput.unselectedStyleAdd.backgroundColor = color("fff");
        FluidFileInput.selectedStyleAdd.backgroundColor = color("ff512f");

    };


}
