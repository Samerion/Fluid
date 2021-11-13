import glui;
import raylib;
import std.format;

void main(string[] flags) {

    SetConfigFlags(ConfigFlags.FLAG_WINDOW_RESIZABLE);
    SetTraceLogLevel(TraceLogLevel.LOG_WARNING);
    InitWindow(800, 600, "Glui HiDPI test");
    SetTargetFPS(60);
    scope (exit) CloseWindow();

    const scale = GetWindowScaleDPI;

    auto root = vscrollFrame(
        .layout!(1, "fill"),
        makeTheme!q{

            font = loadFont("examples/ubuntu.ttf", 22);
            fontSize = 22;
            charSpacing = 0;
            wordSpacing = 0.4;

            GluiLabel.styleAdd;
            GluiButton!().styleAdd!q{

                padding = 0;
                textColor = Colors.BLUE;
                backgroundColor = Colors.BLANK;

                hoverStyleAdd;
                pressStyleAdd;
                focusStyleAdd;

            };

        },

        label("Hello, this is a HiDPI test!\n"),

        label("This example should use HiDPI as long as you have it enabled in your system. Your current configuration "
            ~ format!"will scale the content by %s%%x%s%%\n"(scale.x*100 - 100, scale.y*100 - 100)),

        label("For HiDPI to work correctly, you must use a font you provided yourself. For this reason, instead of "
            ~ "using the default Raylib font, this example uses the Ubuntu font instead.\n"
            ~ "The font is under the Ubuntu font licence, see "),
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
