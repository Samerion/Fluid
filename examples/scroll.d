import fluid;
import raylib;

import std.stdio;
import std.exception;

void main() {

    SetConfigFlags(ConfigFlags.FLAG_WINDOW_RESIZABLE);
    SetTraceLogLevel(TraceLogLevel.LOG_WARNING);
    InitWindow(600, 300, "Scrolling example");
    SetTargetFPS(60);
    SetExitKey(0);
    scope (exit) CloseWindow();

    immutable theme2 = makeTheme!q{

        FluidFrame.styleAdd.backgroundColor = color!"#e62937";

    };

    immutable rightTheme = makeTheme!q{

        FluidSpace.styleAdd!q{
            margin = 5;
            margin.sideY = 10;
        };
        FluidButton!().styleAdd!q{
            margin.sideTop = 10;
        };

    };

    FluidScrollInput myScrollbar, disabledScrollbar;
    FluidButton!() myButton;

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
                myButton = button("Toggle me!", {

                    myButton.text = myButton.text[0] == 'T'
                        ? "Don't toggle me!"
                        : "Toggle me!";
                    myButton.updateSize();

                }),
                label("Lorem\nipsum\ndolor\nsit\namet,\nconsectetur\nadipiscing\nelit"),
            ),
        ),
        vscrollFrame(
            .layout!(1, "fill", "start"),
            rightTheme,
            vspace(

                label("A useless scrollbar:"),
                myScrollbar = hscrollInput(.layout!"fill"),

                button("Change scrollbar position", {

                    myScrollbar.position = !myScrollbar.position * myScrollbar.scrollMax;

                }),

            ),
            vspace(
                hscrollFrame(
                    .layout!"fill",

                    label("A long time ago far far far far far far far far far far far far far far far away..."),

                ),
            ),
            vspace(

                label("Even more useless scrollbar:"),
                disabledScrollbar = hscrollInput(.layout!"fill"),

                textInput("Type something long!"),

            ),

        )
    );

    myScrollbar.availableSpace = 5_000;
    disabledScrollbar.availableSpace = 5_000;
    disabledScrollbar.isDisabled = true;

    while (!WindowShouldClose) {

        BeginDrawing();

            ClearBackground(Colors.WHITE);
            root.draw();

        EndDrawing();

    }

}
