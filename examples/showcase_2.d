import glui;
import raylib;
import std.algorithm;

void main() {

    SetConfigFlags(ConfigFlags.FLAG_WINDOW_RESIZABLE);
    SetTraceLogLevel(TraceLogLevel.LOG_WARNING);
    InitWindow(800, 600, "Glui showcase");
    SetTargetFPS(60);

    scope (exit) CloseWindow();

    auto root = vscrollFrame(
        .layout!(1, "fill"),

        // Customizing the theme...
        makeTheme!q{

            // Some nice padding for frames
            GluiFrame.styleAdd!q{

                padding.sideX = 6;
                backgroundColor = Color(0xff, 0xff, 0xff, 0xaa);

            };

            // Get some nicer background for the main frame
            GluiScrollFrame.styleAdd!q{

                padding.sideX = 6;
                backgroundColor = Colors.SKYBLUE;

            };

        },

        // Add children nodes
        inputExample,
    );

    while (!WindowShouldClose) {

        BeginDrawing();

            ClearBackground(Colors.BLACK);
            root.draw();

        EndDrawing();

    }

}

GluiSpace inputExample() {

    const firstText = "Press one of the buttons below to change text";

    GluiLabel frontLabel;
    GluiTextInput frontInput;
    GluiNode[3] disabledNodes;

    enum never = delegate() => assert(0);

    auto root = vspace(
        .layout!"fill",

        frontLabel = label(firstText),

        hspace(
            .layout!"fill",

            // Regular buttons
            vframe(
                .layout!1,

                label("Regular buttons"),

                vframe(
                    button("Hello", { frontLabel.text = "Hello"; }),
                    button("Hey", { frontLabel.text = "Hey"; }),
                    button("Hi", { frontLabel.text = "Hi"; }),
                ),
                button("Reset", { frontLabel.text = firstText; }),

            ),

            // Disabled buttons
            vframe(
                .layout!1,

                label("Disabled buttons"),

                // We can disable a whole container node to recursively disable its contents
                disabledNodes[0] = vframe(
                    button("Bye", never),
                    button("Goodbye", never),
                ),
                disabledNodes[1] = button("Disabled button", never),

            ),

            // Text input!
            vspace(
                frontInput = textInput("Input custom text", { frontLabel.text = frontInput.value; }),
                disabledNodes[2] = textInput("Disabled input", never),
            ),

        ),

    );

    // Disable all the designated nodes
    disabledNodes[].each!"a.disabled = true";

    return root;

}
