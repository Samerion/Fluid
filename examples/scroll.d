import glui;
import raylib;

import std.stdio;
import std.exception;

void main() {

    SetConfigFlags(ConfigFlag.FLAG_WINDOW_RESIZABLE);
    SetTraceLogLevel(TraceLogType.LOG_WARNING);
    InitWindow(300, 300, "Scrolling example");
    SetTargetFPS(60);
    SetExitKey(0);
    scope (exit) CloseWindow();

    Theme theme = [
        &GluiFrame.styleKey: style!q{ backgroundColor = Colors.WHITE; },
    ];
    Theme theme2 = [
        &GluiFrame.styleKey: style!q{ backgroundColor = Colors.RED; },
    ];

    auto root = vframe(
        theme,
        .layout!(1, "fill"),
        vframe(
            .layout!1,
            theme2,
            label("foo"),
            label("bar"),
            label("Lorem\nipsum\ndolor\nsit\namet,\nconsectetur\nadipiscing\nelit"),
        ),
        vspace(
            .layout!1,
            label("Lorem\nipsum\ndolor\nsit\namet,\nconsectetur\nadipiscing\nelit"),
        ),
    );

    while (!WindowShouldClose) {

        BeginDrawing();

            BeginScissorMode(0, 0, 50, 50);

                ClearBackground(Colors.BLACK);
                root.draw();

            EndScissorMode();

        EndDrawing();

    }

}
