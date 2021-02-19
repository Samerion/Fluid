import glui;
import raylib;

void main() {

    SetConfigFlags(ConfigFlag.FLAG_WINDOW_RESIZABLE);
    InitWindow(800, 600, "Hello, World!");
    SetTargetFPS(60);

    scope (exit) CloseWindow();

    auto style = new Style;
    with (style) {

        backgroundColor = Colors.WHITE;
        textColor       = Colors.BLACK;

    }

    NodeLayout fill = {
        expand: 1,
        nodeAlign: NodeAlign.fill,
    };

    NodeLayout layout = {
        expand: 1,
        nodeAlign: [
            NodeAlign.fill,
            NodeAlign.start,
        ]
    };

    NodeLayout title = {
        expand: 1,
        nodeAlign: NodeAlign.center
    };

    auto root = new GluiFrame(fill).addChild(

        new GluiFrame(style, layout).addChild(
            new GluiLabel(style, title, "Hello, World!")
        ),

    );

    while (!WindowShouldClose) {

        BeginDrawing();

            root.draw();

        EndDrawing();

    }

}
