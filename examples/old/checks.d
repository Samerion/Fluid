// This is more of a test rather than an example.
// It will be moved to a separate directory for automated tests once Glui gets a headless mode.

import glui;
import raylib;

import std.stdio;
import std.exception;

version (none):

void main() {

    SetConfigFlags(ConfigFlags.FLAG_WINDOW_RESIZABLE);
    SetTraceLogLevel(TraceLogLevel.LOG_WARNING);
    InitWindow(800, 600, "Check test");
    SetTargetFPS(60);
    SetExitKey(0);
    scope (exit) CloseWindow();

    immutable theme = makeTheme!q{ };

    auto root = vframe(
        theme,
        vspace(.layout!1, label("NO CRASH PLS")).hide,
        label("Gone!"),
    );

    class BrokenFrame : GluiFrame {

        override void drawImpl(Rectangle outer, Rectangle inner) @trusted {

            debug assertClean(root.children);

            debug {

                assert(root.children.length == 3);
                assert(cast(GluiLabel) root.children[1]),
                assertLocked(root.children);

                assertThrown!Error(root.children = root.children[1..$]);

            }

            super.drawImpl(outer, inner);

        }

    }

    root.children ~= new BrokenFrame;

    debug assertThrown!Error(root.children.assertClean);

    BeginDrawing();

        ClearBackground(Colors.BLACK);
        root.draw();

    EndDrawing();

    writefln!"test passed";

}
