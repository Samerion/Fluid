import glui;
import raylib;

void main() {

    SetConfigFlags(ConfigFlag.FLAG_WINDOW_RESIZABLE);
    SetTraceLogLevel(TraceLogType.LOG_NONE);
    InitWindow(800, 600, "Hello, World!");
    SetTargetFPS(60);

    scope (exit) CloseWindow();

    auto style = new Style()
        .set!"backgroundColor"(Colors.WHITE)
        .set!"textColor"(Colors.BLACK);

    auto bgred = new Style()
        .set!"backgroundColor"(Color(0xc0, 0x12, 0x12, 0xff));

    auto bggreen = new Style()
        .set!"backgroundColor"(Color(0x12, 0xc0, 0x12, 0xff));

    auto bgblue = new Style()
        .set!"backgroundColor"(Color(0x12, 0x12, 0xc0, 0xff));

    NodeLayout fill = {
        expand: 1,
        nodeAlign: NodeAlign.fill,
    };

    NodeLayout header = {
        nodeAlign: [
            NodeAlign.fill,
            NodeAlign.start,
        ]
    };

    NodeLayout title = {
        expand: 1,
        nodeAlign: NodeAlign.center
    };

    NodeLayout column = {
        expand: 1,
        nodeAlign: NodeAlign.fill,
    };

    auto root = new GluiFrame(fill).addChild(

        new GluiFrame(style, header)
            .addChild(
                new GluiLabel(style, title, "Hello, World!")
            ),

        new GluiFrame(fill)
            .set!"directionHorizontal"(true)
            .addChild(
                new GluiFrame(column, bgred),
                new GluiFrame(column, bggreen),
                new GluiFrame(column)
                    .addChild(
                        new GluiFrame(fill, bgblue),
                        new GluiLabel(header, style, "Welcome to Glui!"),
                    ),
            )

    );

    while (!WindowShouldClose) {

        BeginDrawing();

            ClearBackground(Colors.BLACK);
            root.draw();

        EndDrawing();

    }

}
