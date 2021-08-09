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

    Theme theme = [
        &GluiFrame.styleKey: style!q{ },

        &GluiButton!GluiLabel.styleKey: style!q{
            backgroundColor = Color(0xee, 0xee, 0xee, 0xff);
        },

        &GluiScrollBar.backgroundStyleKey: style!q{
            backgroundColor = Color(0xee, 0xee, 0xee, 0xff);
        },
        &GluiScrollBar.styleKey: style!q{
            backgroundColor = Color(0xaa, 0xaa, 0xaa, 0xff);
        },
        &GluiScrollBar.hoverStyleKey: style!q{
            backgroundColor = Color(0x88, 0x88, 0x88, 0xff);
        },
        &GluiScrollBar.focusStyleKey: style!q{
            backgroundColor = Color(0x77, 0x77, 0x77, 0xff);
        },
        &GluiScrollBar.pressStyleKey: style!q{
            backgroundColor = Color(0x55, 0x55, 0x55, 0xff);
        }
    ];
    Theme theme2 = [
        &GluiFrame.styleKey: style!q{ backgroundColor = Colors.RED; },
    ];

    GluiScrollBar myScrollBar;

    auto root = hframe(
        theme,
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
                label("Lorem ipsum dolor sit amet, consectetur adipiscing elit"),
            ),
        ),
        vframe(
            .layout!1,
            label("A useless scrollbar:"),
            myScrollBar = hscrollBar(.layout!"fill"),
            label("..."), // margins are a must
            button("Change scrollbar position", {

                myScrollBar.position = !myScrollBar.position * myScrollBar.scrollMax;

            }),
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
