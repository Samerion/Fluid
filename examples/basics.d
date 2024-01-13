module glui.showcase.basics;

import glui;
import glui.showcase;


@safe:


@(() => label("To start from the basics, user interfaces in Glui are built using Nodes. There's a number of different "
    ~ "node types; Each serves a different purpose and does something different. A good initial example is the "
    ~ "Label node, which can be used to display text. Let's recreate the classic Hello World program."))
GluiNode helloWorldExample() {

    return label("Hello, World!");

}

@(() => label("Nodes as such do nothing and the code above, while used to create a Label, won't display it on the "
    ~ "screen. Typically, you'd like to create a window the user interface can live in. Because Glui is made with "
    ~ "game development in mind, it can integrate with Raylib to do this. A minimal example of using Glui in Raylib "
    ~ "will thus look like this:"))
void raylibExample() @system {

    import raylib;

    // Create the window
    InitWindow(800, 600, "Hello, World!");
    SetTargetFPS(60);
    scope (exit) CloseWindow();

    // Prepare the UI
    auto root = label("Hello, World!");

    // Run the app
    while (!WindowShouldClose) {

        BeginDrawing();
        scope (exit) EndDrawing();

        ClearBackground(Colors.WHITE);

        // Draw the UI
        root.draw();

    }

}

@(
    () => label("This tutorial will focus on Glui however, and won't describe Raylib in detail. If you would like to "
        ~ "learn more about Raylib, visit its homepage:"),
    () => button("https://raylib.com", delegate () @trusted {
        import raylib;
        OpenURL("https://raylib.com");
    }),
    () => label(.headingTheme, "Frames"),
    () => label("Next up in our list of basic nodes is the Frame node."),
    () => label(.subheadingTheme, "Frames"),
    () => label("Next up in our list of basic nodes is the Frame node."),
)
void raylibLinkExample() { }
