import glui;
import raylib;

import std.array;
import std.range;
import std.format;

void main() {

    SetConfigFlags(ConfigFlags.FLAG_WINDOW_RESIZABLE);
    SetTraceLogLevel(TraceLogLevel.LOG_WARNING);
    InitWindow(800, 600, "Hello, World!");
    SetTargetFPS(60);

    scope (exit) CloseWindow();

    auto theme = makeTheme!q{

        GluiFrame.styleAdd!q{

            margin = 10;
            backgroundColor = color!"#fffa";

        };

    };

    auto fancyScroll = makeTheme!q{

        GluiFrame.styleAdd!q{
            backgroundColor = color!"#fffa";
            margin = 10;
            padding = 10;
        };

        GluiScrollInput.styleAdd!q{
            margin = 0;
            margin.sideLeft = 4;
            padding = 4;
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
        hspace(
            .layout!(1, "fill"),
            fancyScroll
            ,
            vscrollFrame(
                .layout!(1, "fill"),

                cast(GluiNode[]) generate(() => label("Line of text")).take(150).array,
            ),
            vscrollFrame(
                .layout!(1, "fill"),
                fancyScroll.makeTheme!q{

                    GluiScrollInput.styleAdd!q{
                        margin = 4;
                        margin.sideRight = 0;
                    };

                },

                cast(GluiNode[]) generate(() => label("Line of text")).take(150).array,
            ),
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
