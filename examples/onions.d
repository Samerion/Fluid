import glui;
import raylib;

void main() {

    SetConfigFlags(ConfigFlag.FLAG_WINDOW_RESIZABLE);
    SetTraceLogLevel(TraceLogType.LOG_WARNING);
    InitWindow(800, 600, "Hello, World!");
    SetTargetFPS(60);
    SetExitKey(0);

    scope (exit) CloseWindow();

    auto theme = makeTheme!q{

        GluiFrame.styleAdd.backgroundColor = Color(0x00, 0x00, 0x00, 0x00);

    };

    auto redTheme = makeTheme!q{

        GluiFrame.styleAdd.backgroundColor = Color(0xc0, 0x12, 0x12, 0xff);

    };

    auto greenTheme = makeTheme!q{

        GluiFrame.styleAdd.backgroundColor = Color(0x12, 0xc0, 0x12, 0xff);

        GluiButton!().styleAdd!q{

            backgroundColor = Color(0xff, 0xff, 0xff, 0xaa);

            hoverStyleAdd.mouseCursor = MouseCursor.MOUSE_CURSOR_POINTING_HAND;

        };

    };
    auto whiteTheme = makeTheme!q{

        GluiFrame.styleAdd.backgroundColor = Color(0xff, 0xff, 0xff, 0xff);
        GluiFilePicker.selectedStyleAdd.backgroundColor = Color(0xff, 0x51, 0x2f, 0xff);

    };

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

            ClearBackground(Colors.BLACK);
            root.draw();

        EndDrawing();

    }

}
