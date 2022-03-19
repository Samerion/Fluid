import glui;
import raylib;
import std.algorithm;

void main() {

    SetConfigFlags(ConfigFlags.FLAG_WINDOW_RESIZABLE);
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
            backgroundColor = Color(0xff, 0xff, 0xff, 0xaa);

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
        inputExample,
        slotExample,
    );

    while (!WindowShouldClose) {

        BeginDrawing();

            ClearBackground(Colors.BLACK);
            root.draw();

        EndDrawing();

    }

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

        frontLabel = label(firstText),

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