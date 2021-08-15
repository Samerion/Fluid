import glui;
import raylib;

import std.array;
import std.range;
import std.format;

void main() {

    SetConfigFlags(ConfigFlag.FLAG_WINDOW_RESIZABLE);
    SetTraceLogLevel(TraceLogType.LOG_NONE);
    InitWindow(800, 600, "Hello, World!");
    SetTargetFPS(60);

    scope (exit) CloseWindow();

    auto theme = makeTheme!q{

        GluiFrame.styleAdd!q{

            margin = 10;
            backgroundColor = Color(0xff, 0xff, 0xff, 0xaa);

        };

    };

    GluiFrame innerExpand;
    GluiSpace root, screen1, screen2;

    screen1 = vspace(
        .layout!(1, "fill"),
        theme,

        vframe(
            button("Switch to screen 2", { root = screen2; }),
        ),
        vframe(
            .layout!"end",
            label("hello"),
        ),
        vframe(
            .layout!"fill",
            label("hello"),
        ),
        vframe(
            .layout!(1, "start"),
            label("hello"),
        ),
        vframe(
            .layout!(1, "fill"),

            innerExpand = hframe(
                .layout!(1, "fill"),
                button("toggle expand", {

                    innerExpand.layout.expand = !innerExpand.layout.expand;
                    innerExpand.updateSize();

                }),
            ),

            label("hello"),
        ),
    );

    screen2 = vspace(
        .layout!(1, "fill"),
        theme,

        vframe(
            button("Switch to screen 1", { root = screen1; }),
        ),
        vscrollFrame(
            .layout!(1, "fill"),
            theme.makeTheme!q{

                GluiFrame.styleAdd!q{
                    backgroundColor = Color(0xff, 0xff, 0xff, 0xaa);
                    margin = 10;
                    padding = 10;
                };

            },

            cast(GluiNode[]) generate(() => label("Line of text")).take(150).array,

        ),
    );

    root = screen1;

    while (!WindowShouldClose) {

        BeginDrawing();

            ClearBackground(Colors.BLACK);
            root.draw();

        EndDrawing();

    }

}
