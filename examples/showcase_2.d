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
    GluiNode[2] disabledNodes;

    auto root = vspace(

        frontLabel = label(firstText),

        // First examples
        vframe(
            button("Hello", { frontLabel.text = "Hello"; }),
            button("Hey", { frontLabel.text = "Hey"; }),
            button("Hi", { frontLabel.text = "Hi"; }),
        ),
        button("Reset", { frontLabel.text = firstText; }),

        // Disabled buttons
        disabledNodes[0] = vframe(
            button("Bye", delegate { assert(0); }),
            button("Goodbye", delegate { assert(0); }),
        ),
        disabledNodes[1] = button("Disabled button", delegate { assert(0); }),

        // A text input

    );

    disabledNodes[].each!"a.disabled = true";

    return root;

}
