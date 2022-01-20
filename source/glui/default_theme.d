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

            backgroundColor = Color(0xee, 0xee, 0xee, 0xff);
            mouseCursor = MouseCursor.MOUSE_CURSOR_POINTING_HAND;

            margin.sideY = 2;
            padding.sideX = 6;

            focusStyleAdd.backgroundColor = Color(0xdd, 0xdd, 0xdd, 0xff);
            hoverStyleAdd.backgroundColor = Color(0xcc, 0xcc, 0xcc, 0xff);
            pressStyleAdd.backgroundColor = Color(0xaa, 0xaa, 0xaa, 0xff);
            disabledStyleAdd!q{

                textColor = Color(0x00, 0x00, 0x00, 0xaa);
                backgroundColor = Color(0xee, 0xee, 0xee, 0x55);

            };

        };

        GluiTextInput.styleAdd!q{

            backgroundColor = Color(0xff, 0xff, 0xff, 0xcc);
            mouseCursor = MouseCursor.MOUSE_CURSOR_IBEAM;

            margin.sideY = 2;
            padding.sideX = 6;

            emptyStyleAdd.textColor = Color(0x00, 0x00, 0x00, 0xaa);
            focusStyleAdd.backgroundColor = Color(0xff, 0xff, 0xff, 0xff);
            disabledStyleAdd!q{

                textColor = Color(0x00, 0x00, 0x00, 0xaa);
                backgroundColor = Color(0xff, 0xff, 0xff, 0x55);

            };

        };

        GluiScrollBar.styleAdd!q{

            backgroundColor = Color(0xaa, 0xaa, 0xaa, 0xff);

            backgroundStyleAdd.backgroundColor = Color(0xee, 0xee, 0xee, 0xff);
            hoverStyleAdd.backgroundColor = Color(0x88, 0x88, 0x88, 0xff);
            focusStyleAdd.backgroundColor = Color(0x77, 0x77, 0x77, 0xff);
            pressStyleAdd.backgroundColor = Color(0x55, 0x55, 0x55, 0xff);
            disabledStyleAdd.backgroundColor = Color(0xaa, 0xaa, 0xaa, 0x55);

        };

        GluiFilePicker.selectedStyleAdd.backgroundColor = Color(0xff, 0x51, 0x2f, 0xff);

    };


}
