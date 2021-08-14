import glui;
import raylib;
import std.format;

void main() {

    SetConfigFlags(ConfigFlag.FLAG_WINDOW_RESIZABLE);
    SetTraceLogLevel(TraceLogType.LOG_NONE);
    InitWindow(800, 600, "Hello, World!");
    SetTargetFPS(60);

    scope (exit) CloseWindow();

    // Create sub-themes for colored backgrounds
    // Tip: To make a new theme from scratch without inheriting Glui defaults, use `Theme.init.makeTheme`
    auto redTheme = makeTheme!q{

        GluiFrame.styleAdd.backgroundColor = Color(0xc0, 0x12, 0x12, 0xff);

    };

    auto greenTheme = makeTheme!q{

        GluiFrame.styleAdd.backgroundColor = Color(0x12, 0xc0, 0x12, 0xff);

    };
    auto blueTheme = makeTheme!q{

        GluiFrame.styleAdd.backgroundColor = Color(0x12, 0x12, 0xc0, 0xff);

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

    auto root = vframe(fill,

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

                button(layout!("fill", "start"),
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

            ClearBackground(Colors.BLACK);
            root.draw();

        EndDrawing();

    }

}
