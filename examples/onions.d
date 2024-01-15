import fluid;
import raylib;

void main() {

    SetConfigFlags(ConfigFlags.FLAG_WINDOW_RESIZABLE);
    SetTraceLogLevel(TraceLogLevel.LOG_WARNING);
    InitWindow(800, 600, "Hello, World!");
    SetTargetFPS(60);
    SetExitKey(0);

    scope (exit) CloseWindow();

    auto redTheme = gluiDefaultTheme.makeTheme!q{

        GluiFrame.styleAdd.backgroundColor = color!"#c01212";

    };
    auto greenTheme = gluiDefaultTheme.makeTheme!q{

        GluiFrame.styleAdd.backgroundColor = color!"#12c012";

    };
    auto whiteTheme = gluiDefaultTheme.makeTheme!q{

        GluiFrame.styleAdd.backgroundColor = color!"#fff";

    };

    GluiFileInput picker;
    GluiLabel fileStatus;
    GluiButton!() unrelatedButton;

    auto root = onionFrame(
        layout(NodeAlign.fill),

        hframe(
            layout(NodeAlign.fill),
            redTheme
        ),
        hspace(
            layout(NodeAlign.fill),
            label("Red background!"),
            vframe(greenTheme,
                layout(NodeAlign.fill),
                label("Green background!"),

                fileStatus = label("Press the text below..."),
                button("Trigger the file picker", { picker.show(); }),

                unrelatedButton = button("An unrelated button", { unrelatedButton.text = "Huh?"; }),
            ),
        ),
        picker = fileInput(whiteTheme, "Pick a file...",
            () {
                fileStatus.text = "Picked " ~ picker.value;
            },
            () {
                fileStatus.text = "Cancelled.";
            }
        ),

    );
    while (!WindowShouldClose) {

        BeginDrawing();

            ClearBackground(Colors.BLACK);
            root.draw();

        EndDrawing();

    }

}
