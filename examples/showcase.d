import glui;
import raylib;
import std.format;

void main() {

    SetConfigFlags(ConfigFlag.FLAG_WINDOW_RESIZABLE);
    SetTraceLogLevel(TraceLogType.LOG_NONE);
    InitWindow(800, 600, "Hello, World!");
    SetTargetFPS(60);

    scope (exit) CloseWindow();

    // Create theme
    auto theme = [

        &GluiFrame.styleKey: style!q{
            backgroundColor = Colors.WHITE;
        },

        &GluiLabel.styleKey: style!q{
            textColor = Colors.BLACK;
        },

        &GluiButton!GluiLabel.styleKey: style!q{
            backgroundColor = Colors.WHITE;
            textColor = Colors.BLACK;
            fontSize = 20;
        },
        &GluiButton!GluiLabel.focusStyleKey: style!q{
            backgroundColor = Color(0xee, 0xee, 0xee, 0xff);
            textColor = Colors.BLACK;
            fontSize = 20;
        },
        &GluiButton!GluiLabel.hoverStyleKey: style!q{
            backgroundColor = Color(0xdd, 0xdd, 0xdd, 0xff);
            textColor = Colors.BLACK;
            fontSize = 20;
        },
        &GluiButton!GluiLabel.pressStyleKey: style!q{
            backgroundColor = Color(0xaa, 0xaa, 0xaa, 0xff);
            textColor = Colors.BLACK;
            fontSize = 20;
        },

        &GluiTextInput.styleKey: style!q{
            backgroundColor = Color(0xff, 0xff, 0xff, 0xcc);
            textColor = Colors.BLACK;
        },
        &GluiTextInput.emptyStyleKey: style!q{
            backgroundColor = Color(0xff, 0xff, 0xff, 0xcc);
            textColor = Color(0x00, 0x00, 0x00, 0xaa);

        },
        &GluiTextInput.focusStyleKey: style!q{
            backgroundColor = Color(0xff, 0xff, 0xff, 0xff);
            textColor = Colors.BLACK;
        }

    ];
    // TODO: create a default theme and use it, also add styleKey helpers

    // Create themes for colored backgrounds
    auto redTheme = theme.dup;
    redTheme[&GluiFrame.styleKey] = style!q{
        backgroundColor = Color(0xc0, 0x12, 0x12, 0xff);
    };
    auto greenTheme = theme.dup;
    greenTheme[&GluiFrame.styleKey] = style!q{
        backgroundColor = Color(0x12, 0xc0, 0x12, 0xff);
    };
    auto blueTheme = theme.dup;
    blueTheme[&GluiFrame.styleKey] = style!q{
        backgroundColor = Color(0x12, 0x12, 0xc0, 0xff);
    };


    auto whiteText = style!q{
        textColor = Colors.WHITE;
    };

    Layout fill = layout!(1, "fill");

    // Save IDs
    GluiNode secondColumn;

    /// A button which will disappear on click.
    GluiButton!() hidingButton() {

        static size_t number;

        GluiButton!() result;
        result = button(format!"Click me! %s"(++number), { result.remove; });
        return result;

    }

    auto root = vframe(theme, fill,

        vframe(layout!("fill", "start"),

            hframe(
                layout!"center",

                imageView("./logo.png", Vector2(40, 40)),
                label(layout!"center", "Hello, Glui!"),
            )

        ),

        hframe(fill,

            vframe(redTheme, fill,

                richLabel(
                    layout!(1, "center"),
                    "Hello, ", whiteText, "World", null, "!\n\n",

                    "Line 1\n",
                    "Line 2\n",
                    whiteText, "Line 3 (but white)\n",
                    null, "Line 4\n",
                ),

                imageView(fill, "./logo.png"),

            ),

            vframe(greenTheme, fill,

                button(layout!("center", "start"),
                    "Press to reveal the rest of this column",

                    {
                        secondColumn.toggleShow();
                    }
                ),

                secondColumn = vframe(

                    label("Second column!"),
                    textInput("Your input..."),

                    // Add a couple of our hiding buttons
                    hidingButton(),
                    hidingButton(),
                    hidingButton(),

                ).hide()

            ),

            vframe(fill,

                vframe(blueTheme, fill,

                    label(layout!(1, "center"), "Third column")

                ),
                label(layout!("center"), "Welcome to Glui!"),

            )

        )

    );

    while (!WindowShouldClose) {

        BeginDrawing();

            SetMouseCursor(MouseCursor.MOUSE_CURSOR_DEFAULT);
            ClearBackground(Colors.BLACK);
            root.draw();

        EndDrawing();

    }

}
