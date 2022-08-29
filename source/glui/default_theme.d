module glui.default_theme;

import glui.style;

immutable Theme gluiDefaultTheme;

shared static this() {

    gluiDefaultTheme = cast(immutable) Theme.init.makeTheme!q{

        fontSize = 20;
        lineHeight = 1.4;
        charSpacing = 0.1;
        wordSpacing = 0.5;

        textColor = Colors.BLACK;

        GluiFrame.styleAdd!q{

            backgroundColor = Colors.WHITE;

        };

        GluiButton!().styleAdd!q{

            backgroundColor = color!"#eee";
            mouseCursor = MouseCursor.MOUSE_CURSOR_POINTING_HAND;

            margin.sideY = 2;
            padding.sideX = 6;

            focusStyleAdd.backgroundColor = color!"#ddd";
            hoverStyleAdd.backgroundColor = color!"#ccc";
            pressStyleAdd.backgroundColor = color!"#aaa";
            disabledStyleAdd!q{

                textColor = color!"#000a";
                backgroundColor = color!"#eee5";

            };

        };

        GluiTextInput.styleAdd!q{

            backgroundColor = color!"#fffc";
            borderStyle = colorBorder(color!"#aaa");
            mouseCursor = MouseCursor.MOUSE_CURSOR_IBEAM;

            margin.sideY = 2;
            padding.sideX = 6;
            border.sideBottom = 2;

            emptyStyleAdd.textColor = color!"#000a";
            focusStyleAdd.backgroundColor = color!"#fff";
            disabledStyleAdd!q{

                textColor = color!"#000a";
                backgroundColor = color!"#fff5";

            };

        };

        GluiScrollBar.styleAdd!q{

            backgroundColor = color!"#aaa";

            backgroundStyleAdd.backgroundColor = color!"#eee";
            hoverStyleAdd.backgroundColor = color!"#888";
            focusStyleAdd.backgroundColor = color!"#777";
            pressStyleAdd.backgroundColor = color!"#555";
            disabledStyleAdd.backgroundColor = color!"#aaa5";

        };

        GluiFilePicker.selectedStyleAdd.backgroundColor = color!"#ff512f";

    };


}
