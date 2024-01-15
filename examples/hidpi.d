import fluid;
import raylib;
import std.format;

void main(string[] flags) {

    SetConfigFlags(ConfigFlags.FLAG_WINDOW_RESIZABLE);
    SetTraceLogLevel(TraceLogLevel.LOG_WARNING);
    InitWindow(800, 600, "Fluid HiDPI test");
    SetTargetFPS(60);
    scope (exit) CloseWindow();

    const scale = GetWindowScaleDPI;

    auto root = vscrollFrame(
        .layout!(1, "fill"),
        makeTheme!q{

            font = loadFont("examples/ubuntu.ttf", 14);

            Label.styleAdd;
            Button!().styleAdd!q{

                padding = 0;
                textColor = color!"0079f1";
                backgroundColor = color!"0000";

                hoverStyleAdd;
                pressStyleAdd;
                focusStyleAdd;

            };

        },

        label("Hello, this is a HiDPI test!\n"),

        label("This example should use HiDPI as long as you have it enabled in your system. Your current configuration "
            ~ format!"will scale the content by %s%%x%s%%\n"(scale.x*100 - 100, scale.y*100 - 100)),

        label("For HiDPI to work correctly, you must use a font you provided yourself. For this reason, instead of "
            ~ "using the default Raylib font, this example uses the Ubuntu font.\n"
            ~ "The font is under the Ubuntu font licence, see:"),
        button("https://ubuntu.com/legal/font-licence",
            delegate() @trusted => OpenURL("https://ubuntu.com/legal/font-licence"))
    );

    while (!WindowShouldClose) {

        BeginDrawing();

            ClearBackground(Colors.WHITE);
            root.draw();

        EndDrawing();

    }

}
