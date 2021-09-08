import glui;
import raylib;
import std.format;

void main() {

    SetConfigFlags(ConfigFlags.FLAG_WINDOW_RESIZABLE);
    SetTraceLogLevel(TraceLogLevel.LOG_NONE);
    InitWindow(800, 600, "Hello, World!");
    SetTargetFPS(60);

    scope (exit) CloseWindow();

    // Create sub-themes for colored backgrounds
    // Tip: To make a new theme from scratch without inheriting Glui defaults, use `Theme.init.makeTheme`
    auto redTheme = makeTheme!q{

        GluiFrame.styleAdd.backgroundColor = Color(0xc0, 0x12, 0x12, 0xff);
        GluiButton!().styleAdd.backgroundColor = Color(0xff, 0xff, 0xff, 0xff);

    };
    auto greenTheme = redTheme.makeTheme!q{

        GluiFrame.styleAdd.backgroundColor = Color(0x12, 0xc0, 0x12, 0xff);

    };
    auto blueTheme = redTheme.makeTheme!q{

        GluiFrame.styleAdd.backgroundColor = Color(0x12, 0x12, 0xc0, 0xff);

    };

    Layout fill = .layout!(1, "fill");

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

        vframe(.layout!("fill", "start"),

            hframe(
                .layout!"center",

                imageView("./logo.png", Vector2(40, 40)),
                label(.layout!"center", "Hello, Glui!"),
            )

        ),

        hframe(fill,

            vframe(redTheme, fill,

                label("Hello!"),

                imageView(fill, "./logo.png"),

            ),

            vframe(greenTheme, fill,

                button(.layout!("fill", "start"),
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

                    vspace(
                        .layout!(1, "fill", "center"),
                        makeTheme!q{

                            GluiLabel.styleAdd!q{
                                margin = 6;
                                padding = 12;
                                backgroundColor = Color(0xff, 0xff, 0xff, 0xaa);
                            };

                        },

                        label(
                            .layout!"fill",
                            "Label with a margin",
                        ),

                        label(
                            .layout!"fill",
                            "Another label with a margin",
                        )

                    ),

                ),
                label(.layout!("center"), "Welcome to Glui!"),

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
