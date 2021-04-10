module glui.file_picker;

import raylib;
import std.path;

import glui.frame;
import glui.label;
import glui.utils;
import glui.style;
import glui.structs;
import glui.text_input;

alias filePicker = simpleConstructor!GluiFilePicker;

/// A file picker node.
///
/// Note, this node is hidden by default, use `show` to show.
class GluiFilePicker : GluiFrame {

    /// Label with the title of the file picker.
    GluiLabel titleLabel;

    /// Text input field containing the currently selected directory or file for the file picker.
    GluiTextInput input;

    alias input this;

    this(Theme theme, string name) {

        super(
            .layout(1, NodeAlign.center, NodeAlign.start),
            theme,

            titleLabel = label(name),
            input = textInput("Path to file..."),
        );

        // Hide the node
        hide();

        // Windows is silly
        version (Windows) input.value = `C:\`;
        else input.value = expandTilde("~");

    }

    this(string name) {

        this(null, name);

    }

    ref inout(string) text() inout {

        return titleLabel.text;

    }

    protected override void resizeImpl(Vector2 space) {

        // Larger windows
        if (space.x > 600) {

            // Add margin
            input.size.x = space.x / 10 + 540;

        }

        else input.size.x = space.x;

        super.resizeImpl(space);

    }

}
