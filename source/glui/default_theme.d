module glui.default_theme;

import glui.style;

immutable Theme gluiDefaultTheme;

shared static this() {

    gluiDefaultTheme = cast(immutable) makeTheme!q{

        fontSize = 20;
        textColor = Colors.BLACK;


        import glui.frame;

        GluiFrame.styleAdd!q{

            backgroundColor = Colors.WHITE;

        };


        import glui.button;

        GluiButton!().styleAdd!q{

            backgroundColor = Colors.WHITE;
            mouseCursor = MouseCursor.MOUSE_CURSOR_POINTING_HAND,

            // Define alternative styles
            focusStyleAdd.backgroundColor = Color(0xee, 0xee, 0xee, 0xff);
            hoverStyleAdd.backgroundColor = Color(0xdd, 0xdd, 0xdd, 0xff);
            pressStyleAdd.backgroundColor = Color(0xaa, 0xaa, 0xaa, 0xff);

        };


        import glui.text_input;

        GluiTextInput.styleAdd!q{

            backgroundColor = Color(0xff, 0xff, 0xff, 0xcc);
            mouseCursor = MouseCursor.MOUSE_CURSOR_IBEAM;

            GluiTextInput.emptyStyleAdd.textColor = Color(0x00, 0x00, 0x00, 0xaa);
            GluiTextInput.focusStyleAdd.backgroundColor = Color(0xff, 0xff, 0xff, 0xff);

        };

        import glui.file_picker;

        GluiFilePicker.selectedStyleAdd.backgroundColor = Color(0xff, 0x51, 0x2f, 0xff);

    };


}
