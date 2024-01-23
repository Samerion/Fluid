/// This module provides a DUB template for `dub init -t fluid`
module fluid.dub_template;

import std.file;
import std.string;
import std.process;

import std.stdio : writefln, stderr;


version (Fluid_InitExec):


void main() {

    const mainFile = q{

        import fluid;
        import raylib;

        void main() {

            // Prepare the window
            SetConfigFlags(ConfigFlags.FLAG_WINDOW_RESIZABLE);
            SetTraceLogLevel(TraceLogLevel.LOG_WARNING);
            InitWindow(800, 600, "Hello, Fluid!");
            SetTargetFPS(60);
            scope (exit) CloseWindow();

            // Create UI
            auto ui = label("Hello, World!");

            // Event loop
            while (!WindowShouldClose) {

                BeginDrawing();
                scope (exit) EndDrawing();

                ClearBackground(color!"fff");

                ui.draw();

            }

        }

    };

    const mainOutdent = mainFile
        .splitLines
        .outdent     // Remove indent
        .join("\n")
        .strip;      // Strip leading & trailing whitespace

    if ("source".exists) {

        stderr.writefln!"fluid: Directory 'source/' already exists, aborting.";
        return;

    }

    // Prepare the source
    mkdir("source");
    write("source/main.d", mainOutdent);
    append(".gitignore", "*.so\n");
    append(".gitignore", "*.so.*\n");

    // Install raylib
    spawnShell("dub add raylib-d").wait;
    spawnShell("dub run raylib-d:install -y -n").wait;

}
