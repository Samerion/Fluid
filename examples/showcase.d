import fluid;
import raylib;
import std.format;

// This showcase is a WIP.

void main() {

    SetConfigFlags(ConfigFlags.FLAG_WINDOW_RESIZABLE);
    SetTraceLogLevel(TraceLogLevel.LOG_WARNING);
    InitWindow(800, 600, "Hello, World!");
    SetTargetFPS(60);

    scope (exit) CloseWindow();

    // Create sub-themes for colored backgrounds
    // Tip: To make a new theme from scratch without inheriting Glui defaults, use `Theme.init.makeTheme`
    auto redTheme = makeTheme!q{

        GluiFrame.styleAdd.backgroundColor = color!"#c01212";
        GluiButton!().styleAdd.backgroundColor = color!"#fff";

    };
    auto greenTheme = redTheme.makeTheme!q{

        GluiFrame.styleAdd.backgroundColor = color!"#12c012";

    };
    auto blueTheme = redTheme.makeTheme!q{

        GluiFrame.styleAdd.backgroundColor = color!"#1212c0";

    };

    Layout fill = .layout!(1, "fill");

    // Save IDs
    GluiFrame secondColumn;

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

                imageView("./logo.png", Vector2(48, 48)),
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
                                backgroundColor = color!"#fffa";
                            };

                        },

                        label(
                            .layout!"fill",
                            "Label with a margin",
                        ),

                        label(
                            .layout!"fill",
                            "Another label with a margin",
                        ),

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
