/// The Glui showcase is a set of examples designed to illustrate core features of Glui and provide a quick start guide
/// to developing applications using Glui.
///
/// This module provides a navigation menu to launch any of the examples, and is the entrypoint of the showcase. While
/// the showcase uses some non-basic techniques to do its thing, it shows among others how to use Glui with Raylib.
module glui.showcase.main;

import glui;
import raylib;


/// The entrypoint prepares the Raylib window. The UI is build in `createUI()`.
void main() {

    // Prepare the window
    SetConfigFlags(ConfigFlags.FLAG_WINDOW_RESIZABLE);
    SetTraceLogLevel(TraceLogLevel.LOG_WARNING);
    InitWindow(800, 600, "Glui showcase");
    SetTargetFPS(60);
    scope (exit) CloseWindow();

    // Create the UI
    auto ui = createUI();

    // Event loop
    while (!WindowShouldClose) {

        BeginDrawing();
        scope (exit) EndDrawing();

        ClearBackground(color!"fff");

        // Glui is by default configured to work with Raylib, so all you need to make them work together is a single
        // call
        ui.draw();

    }

}

GluiSpace createUI() @safe {

    auto content = nodeSlot!GluiNode(.layout!(1, "fill"));

    // All content is scrollable
    return vscrollFrame(
        .layout!"fill",
        sizeLock!vspace(
            .layout!(1, "center", "start"),
            .sizeLimitX(600),
            button("← Back to navigation", delegate { content = exampleList(content); }),
            content = exampleList(content),
        )
    );

}

GluiSpace exampleList(GluiNodeSlot!GluiNode content) @safe {

    import glui.showcase.basics;

    return vframe(
        .layout!"fill",
        label(.layout!"center", "Hello, World!"),
        grid(
            .layout!"fill",
            .segments(3),
            [
                button(.layout!"fill", "Basics", { content = basics; }),
            ],
        ),
    );

}
