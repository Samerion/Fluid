import glui;
import raylib;

void main() {

    SetConfigFlags(ConfigFlag.FLAG_WINDOW_RESIZABLE);
    SetTraceLogLevel(TraceLogType.LOG_NONE);
    InitWindow(800, 600, "Hello, World!");
    SetTargetFPS(60);

    scope (exit) CloseWindow();


    // Create default style
    auto style = new Style;
    style.backgroundColor = Colors.WHITE;
    style.textColor = Colors.BLACK;

    // Create styles for different backgrounds
    auto bgred = new Style;
    bgred.backgroundColor = Color(0xc0, 0x12, 0x12, 0xff);

    auto bggreen = new Style;
    bggreen.backgroundColor = Color(0x12, 0xc0, 0x12, 0xff);

    auto bgblue = new Style;
    bgblue.backgroundColor = Color(0x12, 0x12, 0xc0, 0xff);


    Layout fill = {
        expand: 1,
        nodeAlign: NodeAlign.fill,
    };

    auto root = vframe(style, fill,

        vframe(layout(NodeAlign.fill, NodeAlign.start),

            label(layout(NodeAlign.center), "Hello, World!"),

        ),

        hframe(fill,

            vframe(bgred, fill),
            vframe(bggreen, fill),
            vframe(fill,

                vframe(bgblue, fill,

                    label(layout(1, NodeAlign.center), "Third column")

                ),
                label(layout(NodeAlign.center), "Welcome to Glui!"),

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
