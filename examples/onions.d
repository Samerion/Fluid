import glui;
import raylib;

void main() {

    SetConfigFlags(ConfigFlag.FLAG_WINDOW_RESIZABLE);
    SetTraceLogLevel(TraceLogType.LOG_NONE);
    InitWindow(800, 600, "Hello, World!");
    SetTargetFPS(60);
    SetExitKey(0);

    scope (exit) CloseWindow();

    auto theme = [
        &GluiFrame.styleKey: style!q{
            backgroundColor = Color(0x00, 0x00, 0x00, 0x00);
        },
    ];

    auto redTheme = [
        &GluiFrame.styleKey: style!q{
            backgroundColor = Color(0xc0, 0x12, 0x12, 0xff);
        },
    ];

    auto greenTheme = [
        &GluiFrame.styleKey: style!q{
            backgroundColor = Color(0x12, 0xc0, 0x12, 0xff);
        },
    ];
    auto whiteTheme = [
        &GluiFrame.styleKey: style!q{
            backgroundColor = Color(0xff, 0xff, 0xff, 0xff);
        },
        &GluiFilePicker.selectedStyleKey: style!q{
            backgroundColor = Color(0xff, 0x51, 0x2f, 0xff);
        },
    ];

    GluiFilePicker picker;
    GluiLabel fileStatus;
    GluiButton!() unrelatedButton;

    auto root = onionFrame(
        theme,
        layout(NodeAlign.fill),

        hframe(
            layout(NodeAlign.fill),
            redTheme
        ),
        hframe(
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
        picker = filePicker(whiteTheme, "Pick a file...",
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

            SetMouseCursor(MouseCursor.MOUSE_CURSOR_DEFAULT);
            ClearBackground(Colors.BLACK);
            root.draw();

        EndDrawing();

    }

}
