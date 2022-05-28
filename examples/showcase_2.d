import glui;
import raylib;
import std.algorithm;

void main() {

    SetConfigFlags(ConfigFlags.FLAG_WINDOW_RESIZABLE | ConfigFlags.FLAG_WINDOW_HIGHDPI);
    SetTraceLogLevel(TraceLogLevel.LOG_WARNING);
    InitWindow(800, 600, "Glui showcase");
    SetTargetFPS(60);

    scope (exit) CloseWindow();

    // Let's customize the theme first
    auto theme = makeTheme!q{

        // Vertical margin for spaces
        GluiSpace.styleAdd.margin.sideY = 6;

        // Some nice padding for frames
        GluiFrame.styleAdd!q{

            margin.sideRight = 4;
            padding.sideX = 6;
            backgroundColor = color!"#fffa";

        };

        // Get some nicer background for the main frame
        GluiScrollFrame.styleAdd!q{

            padding.sideX = 6;
            backgroundColor = Colors.SKYBLUE;

        };

    };

    auto root = vscrollFrame(
        .layout!(1, "fill"),

        // Customizing the theme...
        theme,

        // Add children nodes
        boxExample,
        inputExample,
        gridExample,
        sizeLimitExample,
        slotExample,
    );

    while (!WindowShouldClose) {

        BeginDrawing();

            ClearBackground(Colors.BLACK);
            root.draw();

        EndDrawing();

    }

}

GluiSpace boxExample() {

    auto root = vspace(
        .layout!"fill",

        label(.layout!"center", "Boxes"),

        label("To make it easier to style your interface, Glui has a box system similar to HTML."),

        // Space for the boxes so we can make their width align
        vspace(
            .layout!"center",

            hspace(
                .layout!"fill",

                // Margin
                vframe(
                    .layout!"fill",
                    vframe(
                        makeTheme!q{
                            GluiFrame.styleAdd.margin = 16;
                        },
                        label("Frame with margin"),
                    ),
                ),

                // Border
                vframe(
                    .layout!"fill",
                    vframe(
                        makeTheme!q{
                            GluiFrame.styleAdd!q{
                                border = 6;
                                borderStyle = colorBorder(Colors.BLUE);
                            };
                        },
                        label("Frame with border"),
                    ),
                ),

                // Padding
                vframe(
                    .layout!"fill",
                    vframe(
                        makeTheme!q{
                            GluiFrame.styleAdd.padding = 16;
                        },
                        label("Frame with padding"),
                    ),
                ),

            ),

            vframe(
                .layout!"fill",

                vframe(
                    .layout!"fill",
                    makeTheme!q{
                        GluiFrame.styleAdd!q{
                            margin = 16;
                            border.sideX = 6;
                            border.sideY = 4;
                            borderStyle = colorBorder([Colors.DARKBLUE, Colors.BLUE]);
                            padding = 16;
                        };
                    },
                    label("All mixed!"),
                ),
            ),
        ),
    );

    return root;

}

GluiSpace inputExample() {

    const firstText = "Press one of the buttons below to change text";

    GluiLabel frontLabel;
    GluiTextInput frontInput;
    GluiNode[3] disabledNodes;

    enum never = delegate() => assert(0);

    auto root = vspace(
        .layout!"fill",

        label(.layout!"center", "Input handling"),

        frontLabel = label(.layout!"fill", firstText),

        hspace(
            .layout!"fill",

            // Regular buttons
            vframe(
                .layout!1,

                label("Regular buttons"),

                vframe(
                    button("Hello", { frontLabel.text = "Hello"; }),
                    button("Hey", { frontLabel.text = "Hey"; }),
                    button("Hi", { frontLabel.text = "Hi"; }),
                ),
                button("Reset", { frontLabel.text = firstText; }),

            ),

            // Disabled buttons
            vframe(
                .layout!1,

                label("Disabled buttons"),

                // We can disable a whole container node to recursively disable its contents
                disabledNodes[0] = vframe(
                    button("Bye", never),
                    button("Goodbye", never),
                ),
                disabledNodes[1] = button("Disabled button", never),

            ),

            // Fancier stuff
            vframe(
                .layout!1,

                // An outset border button
                button(
                    makeTheme!q{

                        GluiButton!().styleAdd!q{

                            // Default style
                            backgroundColor = color!"#ccc";
                            borderStyle = colorBorder([
                                color!"#fff",
                                color!"#666",
                                color!"#fff",
                                color!"#666",
                            ]);

                            // Sizing
                            border = 3;
                            padding.sideX = 4;
                            padding.sideY = 0;

                            hoverStyleAdd;
                            focusStyleAdd.backgroundColor = color!"#b1c6e4";

                            // Make it inset when pressed
                            pressStyleAdd!q{
                                backgroundColor = color!"#aaa";
                                borderStyle = colorBorder([
                                    color!"#666",
                                    color!"#fff",
                                    color!"#666",
                                    color!"#fff",
                                ]);
                            };
                        };
                    },

                    "Fancy!",
                    { frontLabel.text = "Fancy!"; }
                ),

            ),

            // Text input!
            vspace(
                frontInput = textInput("Input custom text", { frontLabel.text = frontInput.value; }),
                disabledNodes[2] = textInput("Disabled input", never),
            ),

        ),

    );

    // Disable all the designated nodes
    disabledNodes[].each!"a.disabled = true";

    return root;

}

GluiSpace slotExample() {

    GluiNodeSlot!GluiNode slot;
    GluiNodeSlot!GluiNode emptiedSlot;
    GluiNodeSlot!GluiNode[5] slots;

    // Example A
    auto exampleA = vspace(
        label("Press a button to place a node below"),
        slot = nodeSlot!GluiNode(),

        hspace(
            vframe(
                slots[0] = nodeSlot!GluiNode(
                    label("Hello, World!")
                ),
                button("SWAP", { slot.swapSlots(slots[0]); }),
            ),

            vframe(
                slots[1] = nodeSlot!GluiNode(
                    vframe(
                        label("Hi!")
                    ),
                ),
                button("SWAP", { slot.swapSlots(slots[1]); }),
            ),

            vframe(
                slots[2] = nodeSlot!GluiNode(
                    hspace(
                        // Nested slots!
                        slots[3] = nodeSlot!GluiNode(
                            button("Swap", { slots[4].swapSlots(slots[3]); })
                        ),
                        slots[4] = nodeSlot!GluiNode(
                            label("Text")
                        ),
                    ),
                ),
                button("SWAP", { slot.swapSlots(slots[2]); }),
            ),
        ),
    );

    // We can swap between two differently typed slots if they hold nodes of compatible virtual type
    auto slot1 = nodeSlot!GluiNode(.layout!(1, "start"), label("Label 1"));
    auto slot2 = nodeSlot!GluiLabel(.layout!(1, "end"), label("Label 2"));

    // But they will fail to compile if the types cannot intersect
    auto slot3 = nodeSlot!GluiFrame();

    static assert(!__traits(compiles,  // Therefore, this fails to compile
        slot3.swapSlots(slot2)
    ));

    // For ease of use we can also instantiate the node slot with simple constructors like `label`
    static assert(is(typeof(nodeSlot!GluiLabel()) == typeof(nodeSlot!label())));

    // Example B
    auto exampleB = vspace(
        .layout!"fill",
        label("A backend example: see the code!"),
        hspace(
            .layout!"fill",
            slot1,
            label("---"),
            slot2
        ),
        button("SWAP", { slot1.swapSlots(slot2); })
    );

    auto root = vspace(
        .layout!"fill",

        label(.layout!"center", "Complex tree management with node slots"),
        exampleA,
        exampleB,
    );

    return root;

}

GluiSpace sizeLimitExample() {

    auto root = vspace(
        .layout!"fill",

        label(.layout!"center", "Limiting node size with size locks"),
        label("Size locks will adjust node size closely to the one you want, but will still shrink if needed to ensure"
            ~ " responsiveness."),

        hspace(
            .layout!"fill",

            sizeLock!vframe(
                .layout!(1, "center"),
                .sizeLimitX(100),

                label("This node will not be wider than 100 pixels"),
            ),

            sizeLock!vframe(
                .layout!(1, "center"),
                .sizeLimitX(300),

                label("Even if contents are"),
                label("smaller than the limit,"),
                label("the box will expand"),
                label("if it can..."),
            ),

            sizeLock!hframe(
                .layout!(1, "center"),
                .sizeLimitY(50),

                label("Look into "),
                label("the code!"),
                // Creating size-locked nodes is easy and convenient and works with any node type through a
                // template! It accepts any node class or node constructor like hframe.
                //
                //      sizeLock!GluiLabel
                //      sizeLock!label
                //      sizeLock!vframe
                //      sizeLock!hframe
            ),

        ),
    );

    return root;

}

GluiSpace gridExample() {

    GluiSpace root;

    root = vspace(
        .layout!"fill",

        label(.layout!"center", "Grids"),

        grid(
            .layout!"fill",
            .segments!4,

            label("You can make tables and grids with GluiGrid"),
            [
                label("This"),
                label("Is"),
                label("A"),
                label("Grid"),
            ],
            [
                label(.segments!2, "Multiple columns"),
                label(.segments!2, "For a single cell"),
            ],
        ),

    );

    return root;

}
