import fluid;
import raylib;

version (none):

void main() {

    SetConfigFlags(ConfigFlags.FLAG_WINDOW_RESIZABLE);
    SetTraceLogLevel(TraceLogLevel.LOG_WARNING);
    InitWindow(800, 600, "Map test");
    SetTargetFPS(60);

    scope (exit) CloseWindow();

    MapSpace root;
    HoverButton!() draggableButton;

    root = mapSpace(
        .layout!(1, "fill"),
        makeTheme!q{
            Frame.styleAdd.backgroundColor = color!"#aaa";
        },

        // A button to toggle overlap
        Vector2(0, 0), button("Toggle overflow", () @trusted {
            root.preventOverflow = !root.preventOverflow;
        }),

        // Sample elements
        Vector2(100, 200), label("Hello, World!"),
        Vector2(-50, 30),  label("Overlapping label"),

        // Place one label relative to its end
        dropVector!("end", "start"),
        Vector2(0, 100), label("Hidden text"),

        // A centered text
        Vector2(50, 140), label("Left align"),
        dropVector!("center", "start"),
        Vector2(50, 160), label("Center align"),

        // Just an informative label
        Vector2(100, 550), label("Try to resize the window!"),

        // A little "dropdown" frame
        dropVector!"auto",
        Vector2(300, 150),
        vframe(
            label("Hello,"),
            label("World!"),
            label("How's"),
            label("it"),
            label("going"),
        ),

        // A proper dropdown
        Vector2(0, 300),
        button("Show a dropdown", () @trusted {

            auto position = MapPosition(GetMousePosition, dropVector!"auto");

            root.addFocusedChild(
                popupFrame(
                    label("I'm a dropdown"),
                    button("Button 1", delegate { }),
                    button("Button 2", delegate { }),
                ),
                position,
            );

        }),

        // We need to go deeper!
        Vector2(300, 400),
        vframe(
            mapSpace(
                label("We need"),
                Vector2(40, 40), label("to go"),
                Vector2(80, 80), label("deeper!"),
            ),
        ),

        // A node that can be dragged
        Vector2(300, 30),
        draggableButton = hoverButton("Drag this button!", () @trusted {

            enum mouseButton = MouseButton.MOUSE_BUTTON_LEFT;

            // Pressing the button
            if (IsMouseButtonPressed(mouseButton)) {

                // Drag it!
                root.mouseDrag(draggableButton);

            }

            // Released it
            if (IsMouseButtonReleased(mouseButton)) {

                root.stopMouseDrag();

            }

        }),
    );

    while (!WindowShouldClose) {

        BeginDrawing();

            ClearBackground(Colors.WHITE);
            root.draw();

        EndDrawing();

    }

}
