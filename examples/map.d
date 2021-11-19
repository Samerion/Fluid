import glui;
import raylib;

void main() {

    SetConfigFlags(ConfigFlags.FLAG_WINDOW_RESIZABLE);
    SetTraceLogLevel(TraceLogLevel.LOG_WARNING);
    InitWindow(800, 600, "Map test");
    SetTargetFPS(60);

    scope (exit) CloseWindow();

    GluiMapFrame root;

    root = mapFrame(
        .layout!(1, "fill"),

        // A button to toggle overlap
        Vector2(0, 0), button("Toggle overlap", () @trusted {
            root.preventOverlap = !root.preventOverlap;
        }),

        // Sample elements
        Vector2(200, 200), label("Hello, World!"),
        Vector2(-50, 60),  label("Overlapping label"),
        Vector2(300, 500), label("Try to resize the window!"),

        // We need to go deeper!
        Vector2(300, 300), mapFrame(
            makeTheme!q{
                GluiFrame.styleAdd.backgroundColor = Color(0xaa, 0xaa, 0xaa, 0xff);
            },
            label("We need"),
            Vector2(40, 40), label("to go"),
            Vector2(80, 80), label("deeper!"),
        ),
    );

    while (!WindowShouldClose) {

        BeginDrawing();

            ClearBackground(Colors.WHITE);
            root.draw();

        EndDrawing();

    }

}
