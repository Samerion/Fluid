module glui.showcase.introduction;

import glui;
import glui.showcase;


@safe:


@(
    () => label("Glui is a library for creating user user interfaces. The focus of the library is ease of use, making "
        ~ "it possible to design menus, input forms, controls and displays while minimizing amount of effort and "
        ~ "time."),
    () => label("To start from the basics, Glui programs are built using nodes. There's a number of "
        ~ "different node types; Each serves a different purpose and does something different. A good "
        ~ "initial example is the label node, which can be used to display text. Let's recreate the classic Hello "
        ~ "World program.")
)
GluiLabel helloWorldExample() {

    return label("Hello, World!");

}

@(() => label("Nodes as such do nothing, and the code above, while used to create a label, won't display it on the "
    ~ "screen by itself. Typically, you'd like to create a window the user interface can live in. Because Glui is made "
    ~ "with game development in mind, it can integrate with Raylib to do this. A minimal example of using Glui in "
    ~ "Raylib will thus look like this:"))
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
    () => label("Next up in our list of basic nodes is the frame node. Frames are containers, which means they connect "
        ~ "a number of nodes together. To start, we can place a few labels in a column."),
)
GluiFrame vframeExample() {

    return vframe(
        label("First line"),
        label("Second line"),
        label("Third line"),
    );

}

@(
    () => label("Frames have two core variants, the vframe, and the hframe. The difference is that the vframe aligns "
        ~ "nodes vertically, while hframe aligns them horizontally."),
)
GluiFrame hframeExample() {

    return hframe(
        label("Left, "),
        label("right"),
    );

}

@(
    () => label("The example above makes it look like if there was only a single label. Let's try something more "
        ~ "exciting and insert a vframe inside of the hframe"),
)
GluiFrame bothFramesExample() {

    return hframe(
        label("Left, "),
        vframe(
            label("right"),
            label("down under"),
        ),
    );

}

@(
    () => label("Building Glui apps comes down mostly to combining container nodes like frames with nodes that display "
        ~ "containers or take input. The frame system is flexible enough to support a large number of usecases. Please "
        ~ "follow to the next chapter to learn more about building layout with frames."),
)
void endExample() { }
