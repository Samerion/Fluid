/// Glui is a somewhat minimalistic and declarative high-level UI library for D.
///
/// Glui aims to be as simple in usage as it can be making as much possible with no excess of code. It's built
/// empirically, making each component suitable for all the most common needs out of the box.
///
/// ---
/// auto node = label("Hello, World!");
/// node.draw();
/// ---
module glui;

public import
    glui.backend,
    glui.actions,
    glui.button,
    glui.children,
    glui.default_theme,
    glui.file_input,
    glui.frame,
    glui.grid,
    glui.hover_button,
    glui.image_view,
    glui.input,
    glui.label,
    glui.map_space,
    glui.node,
    glui.onion_frame,
    glui.popup_button,
    glui.popup_frame,
    glui.scroll,
    glui.scroll_input,
    glui.size_lock,
    glui.slot,
    glui.space,
    glui.structs,
    glui.style,
    glui.text_input,
    glui.utils;

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
