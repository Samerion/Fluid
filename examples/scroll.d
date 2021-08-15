import glui;
import raylib;

import std.stdio;
import std.exception;

void main() {

    SetConfigFlags(ConfigFlag.FLAG_WINDOW_RESIZABLE);
    SetTraceLogLevel(TraceLogType.LOG_WARNING);
    InitWindow(600, 300, "Scrolling example");
    SetTargetFPS(60);
    SetExitKey(0);
    scope (exit) CloseWindow();

    immutable theme2 = makeTheme!q{

        GluiFrame.styleAdd.backgroundColor = Colors.RED;

    };

    immutable rightTheme = makeTheme!q{

        GluiSpace.styleAdd!q{
            margin = 5;
            margin[Style.Side.top..$] = 10;
        };
        GluiButton!().styleAdd!q{
            margin[Style.Side.top] = 10;
        };

    };

    GluiScrollBar myScrollBar;

    auto root = hframe(
        .layout!(1, "fill"),
        vspace(
            .layout!("fill"),
            vframe(
                .layout!(1, "fill"),
                theme2,
                label("foo"),
                label("bar"),
                label("Lorem\nipsum\ndolor\nsit\namet,\nconsectetur\nadipiscing\nelit"),
            ),
            vscrollFrame(
                .layout!(1, "fill"),
                label("foo"),
                label("Lorem\nipsum\ndolor\nsit\namet,\nconsectetur\nadipiscing\nelit"),
            ),
        ),
        vframe(
            .layout!1,
            rightTheme,
            vspace(

                label("A useless scrollbar:"),
                myScrollBar = hscrollBar(.layout!"fill"),

                button("Change scrollbar position", {

                    myScrollBar.position = !myScrollBar.position * myScrollBar.scrollMax;

                }),

            ),
            vspace(
                hscrollFrame(
                    .layout!"fill",

                    label("A long time ago far far far far far far far far far far far far far far far away..."),

                ),
            ),

        )
    );

    myScrollBar.availableSpace = 5_000;

    while (!WindowShouldClose) {

        BeginDrawing();

            ClearBackground(Colors.WHITE);
            root.draw();

        EndDrawing();

    }

}
