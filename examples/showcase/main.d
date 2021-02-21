import glui;
import raylib;

void main() {

    SetConfigFlags(ConfigFlag.FLAG_WINDOW_RESIZABLE);
    SetTraceLogLevel(TraceLogType.LOG_NONE);
    InitWindow(800, 600, "Hello, World!");
    SetTargetFPS(60);

    scope (exit) CloseWindow();

    // Create theme
    auto theme = [
        &GluiFrame.styleKey: style!q{
            backgroundColor = Colors.WHITE;
        },
        &GluiLabel.styleKey: style!q{
            textColor = Colors.BLACK;
        },
        &GluiButton!GluiLabel.styleKey: style!q{
            backgroundColor = Colors.WHITE;
            textColor = Colors.BLACK;
            fontSize = 20;
        },
        &GluiButton!GluiLabel.hoverStyleKey: style!q{
            backgroundColor = Color(0xdd, 0xdd, 0xdd, 0xff);
            textColor = Colors.BLACK;
            fontSize = 20;
        },
    ];

    // Create themes for colored backgrounds
    auto redTheme = theme.dup;
    redTheme[&GluiFrame.styleKey] = style!q{
        backgroundColor = Color(0xc0, 0x12, 0x12, 0xff);
    };
    auto greenTheme = theme.dup;
    greenTheme[&GluiFrame.styleKey] = style!q{
        backgroundColor = Color(0x12, 0xc0, 0x12, 0xff);
    };
    auto blueTheme = theme.dup;
    blueTheme[&GluiFrame.styleKey] = style!q{
        backgroundColor = Color(0x12, 0x12, 0xc0, 0xff);
    };

    Layout fill = {
        expand: 1,
        nodeAlign: NodeAlign.fill,
    };

    auto secondColumn = vframe(

        label("Second column!"),

    );
    secondColumn.hide();

    auto root = vframe(theme, fill,

        vframe(layout(NodeAlign.fill, NodeAlign.start),

            label(layout(NodeAlign.center), "Hello, World!"),

        ),

        hframe(fill,

            vframe(redTheme, fill),

            vframe(greenTheme, fill,

                button(layout(NodeAlign.center, NodeAlign.start),
                    "Press to reveal the rest of this column",

                    () {
                        secondColumn.toggleShow();
                    }
                ),
                secondColumn,

            ),

            vframe(fill,

                vframe(blueTheme, fill,

                    label(layout(1, NodeAlign.center), "Third column")

                ),
                label(layout(NodeAlign.center), "Welcome to Glui!"),

            )

        )

    );

    while (!WindowShouldClose) {

        BeginDrawing();

            SetMouseCursor(MouseCursor.MOUSE_CURSOR_DEFAULT);
            ClearBackground(Colors.BLACK);
            root.draw();

        EndDrawing();

    }

}
