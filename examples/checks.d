// This is more of a test rather than an example.
// It will be moved to a separate directory for automated tests once Glui gets a headless mode.

import glui;
import raylib;

import std.stdio;
import std.exception;

void main() {

    SetConfigFlags(ConfigFlag.FLAG_WINDOW_RESIZABLE);
    SetTraceLogLevel(TraceLogType.LOG_WARNING);
    InitWindow(800, 600, "Check test");
    SetTargetFPS(60);
    SetExitKey(0);
    scope (exit) CloseWindow();

    Theme theme = makeTheme!q{ };

    auto root = vframe(
        theme,
        label("Gone!"),
    );

    class BrokenFrame : GluiFrame {

        override void drawImpl(Rectangle rect) {

            debug {

                assert(root.children.length == 2);
                assert(cast(GluiLabel) root.children[0]),
                assertLocked(root.children);

                assertThrown!Error(root.children = root.children[1..$]);

            }

            super.drawImpl(rect);

        }

    }

    root.children ~= new BrokenFrame;

    BeginDrawing();

        ClearBackground(Colors.BLACK);
        root.draw();

    EndDrawing();

    writefln!"test passed";

}
