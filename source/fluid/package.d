/// Fluid is a somewhat minimalistic and declarative high-level UI library for D.
///
/// Fluid aims to be as simple in usage as it can be making as much possible with no excess of code. It's built
/// empirically, making each component suitable for all the most common needs out of the box.
///
/// ---
/// auto node = label("Hello, World!");
/// node.draw();
/// ---
module fluid;

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
    fluid.backend,
    fluid.actions,
    fluid.button,
    fluid.checkbox,
    fluid.children,
    fluid.default_theme,
    fluid.file_input,
    fluid.field_slot,
    fluid.frame,
    fluid.grid,
    fluid.hover_button,
    fluid.image_view,
    fluid.input,
    fluid.label,
    fluid.map_frame,
    fluid.node,
    fluid.number_input,
    fluid.onion_frame,
    fluid.popup_button,
    fluid.popup_frame,
    fluid.radiobox,
    fluid.scroll,
    fluid.scroll_input,
    fluid.size_lock,
    fluid.slider,
    fluid.slot,
    fluid.space,
    fluid.structs,
    fluid.style,
    fluid.switch_slot,
    fluid.text,
    fluid.text_input,
    // Note: fluid.theme is not included
    fluid.tree,
    fluid.utils;

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
