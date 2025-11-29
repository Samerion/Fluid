/// Fluid is a declarative library to build graphical user interfaces. Done the D way,
/// the Fluid way.
///
/// These pages serve as the reference documentation for the library. For the time being, there
/// are no recommended learning resources, but you can get a quickstart using the tour:
///
/// ```sh
/// dub run fluid:tour
/// ```
///
/// Import Fluid per module, or all at once:
///
/// ---
/// import fluid;
/// ---
module fluid;

/// ## General nodes
///
/// In Fluid, most things are accomplished with nodes. The most basic task a node can do is
/// displaying text or providing interaction.
///
/// * [Label][fluid.label] can be used to display text on the screen.
/// * [Button][fluid.button] is a clickable button.
/// * [ImageView][fluid.image_view] displays images.
/// * [ProgressBar][fluid.progress_bar] shows completion status of an operation.
/// * [Separator][fluid.separator] draws a line to separate unrelated content.
///
/// <!-- -->
@("Node reference example")
unittest {
    run(
        label("Hello, World!")
    );
}

/// ## Layout nodes
///
/// > Note: Documentation for this section is incomplete.
///
/// A single node isn't very useful on its own — but nodes can be composed together.
/// Using handy layout nodes like [Frame] or [Space] you can arrange other nodes on the screen.
/// Use a [NodeSlot] to quickly switch between displayed nodes.
///
/// * [DragSlot][fluid.drag_slot] can be dragged and rearranged by the user.
/// * [FieldSlot][fluid.field_slot] associates input with informative nodes, expanding hit regions.
/// * [Frame][fluid.frame] is a more general, styleable variant of `space`.
/// * [GridFrame][fluid.grid] creates a grid layout.
/// * [MapFrame][fluid.map_frame] places nodes in arbitrary positions.
/// * [NodeSlot][fluid.slot] wraps a node for quick replacement.
/// * [OnionFrame][fluid.onion_frame] stacks nodes on top of each other (layers).
/// * [PopupButton][fluid.popup_button] is a handy shortcut for building dropdown menus.
/// * [PopupFrame][fluid.popup_frame] displays outside of regular layout flow.
/// * [Space][fluid.space] aligns nodes in a column or row.
/// * [ScrollFrame][fluid.scroll_frame] allows scrolling through a lot of content.
/// * [SwitchSlot][fluid.switch_slot] (experimental) changes layouts for different screen sizes.
///
/// <!-- -->
@("Layout nodes reference example")
unittest {
    run(
        vspace(
            label("This text displays above"),
            label("This text displays below"),
        ),
    );
}

/// ## Input nodes
///
/// > Note: Documentation for this section is incomplete.
///
/// Get information from the user using input nodes.
///
/// * [Button][fluid.button] is a clickable button.
/// * [Checkbox][fluid.checkbox] is a box that can be selected and deselected.
/// * [CodeInput][fluid.code_input] is a code editor with syntax highlighting.
/// * [FieldSlot][fluid.field_slot] associates input with informative nodes, expanding hit regions.
/// * [NumberInput][fluid.number_input] takes a number and does basic math.
/// * [PasswordInput][fluid.password_input] takes a sensitive passphrase, without displaying it.
/// * [Radiobox][fluid.radiobox] allows selecting one out of multiple options.
/// * [ScrollInput][fluid.scroll_input] is a bare scrollbar.
/// * [SizeLock][fluid.size_lock] restricts maximum size of a node for responsive layouts.
/// * [Slider][fluid.slider] selects one out of multiple values of a range.
/// * [TextInput][fluid.text_input] takes text — a single line, or many.
///
/// <!-- -->
@("Input node reference example")
unittest {
    TextInput name;
    Checkbox agreement;
    run(
        vframe(
            fieldSlot!vspace(
                label("Your name"),
                name = lineInput(),
            ),
            fieldSlot!hspace(
                agreement = checkbox(),
                label("I agree to the rules"),
            ),
            button("Continue", delegate { }),
        ),
    );
}

/// ## Theming
///
/// > Note: Documentation for this section is incomplete.
///
/// Fluid apps can be styled with a stylesheet.
///
/// * [fluid.style][fluid.style] contains a list of stylable properties.
/// * [fluid.theme][fluid.theme] offers a declarative way of building stylesheets.
/// * [fluid.default_theme][fluid.default_theme] defines Fluid's default look.
///
/// <!-- -->
@("Theming example")
unittest {

    import fluid.theme;

    auto theme = Theme(
        rule!Frame(
            margin.sideY = 4,
            backgroundColor = color("#6abbe8"),
            gap = 4,
        ),
    );

}

/// ## Tree actions
///
/// > Note: Documentation for this section is incomplete.
///
/// Manipulate the node tree: search, modify, interact, automate, test, by hooking into tree
/// events with Fluid's [tree actions][fluid.tree.TreeAction].
///
/// * [fluid.actions][fluid.actions] contains a basic collection of tree actions.
/// * [TestSpace][fluid.test_space] can automatically test your nodes.
/// * [Publishers and Subscribers][fluid.future.pipe] (experimental) control asynchronous tasks.
///
/// Other tree actions are currently scattered across [fluid.io][fluid.io].
@("Tree actions reference example")
unittest {
    auto ui = vspace(
        label("A tree action can click this button"),
        button("Click me!", delegate { }),
    );
    ui.focusChild()
        .then((Focusable child) => child
            .runInputAction!(FluidInputAction.press));
}

/// ## Your own nodes
///
/// > Note: Documentation for this section is incomplete.
///
/// Extend a class from [Node] or any other Fluid node to extend Fluid's functionality.
/// See [fluid.node][fluid.node] for a reference.
@("Custom nodes example")
unittest {

    // Define your node's behavior with a Node class
    class ColoredRectangle : Node {
        CanvasIO canvasIO;
        Vector2 size;

        override void resizeImpl(Vector2 space) {
            require(canvasIO);
            minSize = size;
        }

        override void drawImpl(Rectangle outer, Rectangle inner) {
            canvasIO.drawRectangle(inner,
                color("#600"));
        }
    }

    // Construct the node with a node builder
    alias rectangle = nodeBuilder!ColoredRectangle;

}

version (Fluid_Docs) {

    /// ## Input and output
    ///
    /// > Note: Documentation for this section is incomplete.
    ///
    /// Fluid does not communicate with the operating system on its own. To display content on the
    /// screen, and to take input from the keyboard and mouse, it uses a set of I/O nodes.
    ///
    /// * [fluid.io][fluid.io] defines standard interfaces for I/O processing.
    /// * [RaylibView and RaylibStack][fluid.raylib_view] implement Raylib support.
    /// * Legacy: [fluid.backend][fluid.backend] contains the old I/O interfaces.
    /// * [NodeChain][fluid.node_chain] is an optimized base class for I/O implementations.
    ///
    /// ### Transformation
    ///
    /// * [hoverTransform][fluid.hover_transform] remaps mouse input to different screen areas.
    /// * [resolutionOverride][fluid.resolution_override] forces rendering at set resolution.
    ///
    /// ### Low-level
    ///
    /// Nodes for unit testing and for specialized use-cases.
    ///
    /// * [ArsdImageChain][fluid.arsd_image_chain] loads images using `arsd`.
    /// * [ClipboardChain][fluid.clipboard_chain] implements local (non-system) clipboard.
    /// * [FileChain][fluid.file_chain] implements basic file system access through Phobos.
    /// * [FocusChain][fluid.focus_chain] keeps track of the currently focused node.
    /// * [HoverChain][fluid.hover_chain] maps mouse pointer input to nodes.
    /// * [InputMapChain][fluid.input_map_chain] maps button presses to input actions.
    /// * [OverlayChain][fluid.overlay_chain] provides space for popup frames and similar.
    /// * [PreferenceChain][fluid.preference_chain] loads common user preferences.
    /// * [TimeChain][fluid.time_chain] reads time passed with the system clock.
    /// * [TimeMachine][fluid.time_machine] fakes passage of time for testing.
    ///
    /// <!-- -->
    @("I/O reference example with Raylib")
    unittest {
        auto root = raylibStack(
            label("I'm displayed with Raylib!"),
        );
        while (!WindowShouldClose) {
            BeginDrawing();
            root.draw();
            EndDrawing();
        }
    }

}

// Unsupported build flag; ignores checks. Do not file issue tickets if you run into problems when building with it.
debug (Fluid_Force) version = Fluid_Force;
version (Fluid_Force) { }
else {

    // OSX builds are not supported with DMD. LDC is required.
    version (DigitalMars)
    version (OSX) {

        static assert(false,
            "Fluid: DMD is not supported under macOS because of compiler bugs. Refusing to build.\n"
            ~ "    Please use LDC instead. When using dub, pass flag `--compiler=ldc2`.\n"
            ~ "    To ignore this check, you can build with UNSUPPORTED version or debug version Fluid_Force.");

    }
}

public import
    fluid.backend,             // documented
    fluid.actions,             // documented
    fluid.arsd_image_chain,    // documented
    fluid.button,              // documented
    fluid.checkbox,            // documented
    fluid.children,            // skipped    https://git.samerion.com/Samerion/Fluid/issues/397
    fluid.clipboard_chain,     // documented
    fluid.code_input,          // documented
    fluid.default_theme,       // skipped    https://git.samerion.com/Samerion/Fluid/issues/216
    fluid.drag_slot,           // documented
    fluid.file_chain,          // documented
    fluid.file_input,          // skipped    (disabled)
    fluid.field_slot,          // documented
    fluid.frame,               // documented
    fluid.focus_chain,         // documented
    fluid.grid,                // documented
    fluid.hover_button,        // skipped    (deprecated)
    fluid.hover_chain,         // documented
    fluid.hover_transform,     // documented
    fluid.image_view,          // documented
    fluid.input,               // skipped    #216
    fluid.input_map_chain,     // documented
    fluid.io,                  // documented
    fluid.label,               // documented
    fluid.map_frame,           // documented
    fluid.node,                // documented
    fluid.node_chain,          // documented
    fluid.number_input,        // documented
    fluid.onion_frame,         // documented
    fluid.overlay_chain,       // documented
    fluid.password_input,      // documented
    fluid.popup_button,        // documented
    fluid.popup_frame,         // documented
    fluid.preference_chain,    // documented
    fluid.progress_bar,        // documented
    fluid.radiobox,            // documented
    fluid.raylib_view,         // documented
    fluid.resolution_override, // documented
    fluid.scroll,              // documented
    fluid.scroll_input,        // documented
    fluid.separator,           // documented
    fluid.size_lock,           // documented
    fluid.slider,              // documented
    fluid.slot,                // documented
    fluid.space,               // documented
    fluid.structs,             // skipped    #216
    fluid.style,               // documented
    fluid.switch_slot,         // documented
    fluid.test_space,          // documented
    fluid.time_chain,          // documented
    fluid.time_machine,        // documented
    fluid.text,                // skipped    #216
    fluid.text_input,          // documented
    // Note: fluid.theme is not included
    fluid.tree,                // skipped    #216
    fluid.utils;               // skipped    #216

unittest {

    auto root = onionFrame(
        .layout!"fill",

        vframe(
            label("Hello, World!"),
            button("Some input", delegate { }),
        ),

        hframe(
            imageView("logo.png"),
            textInput("Input text here"),
        ),

        popupButton(
            "Click me!",
            vspace(
                hspace(.layout!"fill", vscrollInput()),
                hscrollFrame(label("Hello, World!")),
            ),
        ),
    );

}

@("Legacy: readme.md example (migrated)")
unittest {

    import std.math;

    auto io = new HeadlessBackend;
    auto root = vspace(
        .layout!"center",
        label(.layout!"center", "Hello World from"),
        imageView("./logo.png", Vector2(499, 240)),
    );

    root.io = io;
    root.draw();

    // This should render two textures
    auto textTexture = io.textures.front;
    io.textures.popFront;
    auto imageView = io.textures.front;

    // Both textures should have the same bottom line
    assert(textTexture.rectangle.end.y.isClose(imageView.rectangle.end.y));

}

@("readme.md example")
unittest {

    import std.math;

    auto ui = vspace(
        .layout!"center",
        label(
            .layout!"center",
            "Hello World from"
        ),
        imageView(
            "./logo.png",
            Vector2(499, 240)
        ),
    );
    auto root = testSpace(ui);

    root.draw();

    // This should render two textures
    root.drawAndAssert(
        ui.children[0].drawsImage,
        ui.children[1].drawsImage,
    );

}
