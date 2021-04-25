module glui.file_picker;

import raylib;
import std.conv;
import std.file;
import std.path;
import std.range;
import std.algorithm;

import glui.frame;
import glui.label;
import glui.utils;
import glui.input;
import glui.style;
import glui.structs;
import glui.rich_label;
import glui.text_input;

alias filePicker = simpleConstructor!GluiFilePicker;

/// A file picker node.
///
/// Note, this node is hidden by default, use `show` to show.
class GluiFilePicker : GluiInput!GluiFrame {

    /// Callback to run when input was cancelled.
    void delegate() cancelled;

    /// Max amount of suggestions that can be provided.
    uint suggestionLimit = 10;

    private {

        /// Last saved focus state.
        ///
        /// Used to cancel when the focus is lost and to autofocus when opened.
        bool savedFocus;

        /// Label with the title of the file picker.
        GluiLabel titleLabel;

        /// Text input field containing the currently selected directory or file for the file picker.
        GluiTextInput input;

        /// Label with suggestions to the text.
        GluiRichLabel suggestions;

    }

    this(Theme theme, string name, void delegate() submitted, void delegate() cancelled = null) {

        super(
            .layout(1, NodeAlign.center, NodeAlign.start),
            theme,

            titleLabel  = label(name),
            input       = textInput("Path to file...", submitted),
            suggestions = richLabel(),
        );

        this.cancelled = cancelled;

        // Hide the node
        hide();

        // Windows is silly
        version (Windows) input.value = `C:\`;
        else input.value = expandTilde("~/");

        // Bind events
        input.changed = () {
            if (changed) changed();
            updateSuggestions();
        };

        input.submitted = () {
            if (submitted) submitted();

            // Automatically hide when submitted
            hide();
        };

    }

    this(string name, void delegate() submitted, void delegate() cancelled = null) {

        this(null, name, submitted, cancelled);

    }

    ref inout(string) text() inout {

        return titleLabel.text;

    }

    ref inout(string) value() inout {

        return input.value;

    }

    /// Cancel picking files, triggering `cancelled` event.
    void cancel() {

        // Call callback if it exists
        if (cancelled) cancelled();

        // Hide
        hide();

        savedFocus = false;
        super.isFocused = false;

    }

    /// Refresh the suggestion list.
    void updateSuggestions() {

        const split = value.retro.array.findSplitBefore("/");
        const dir  = split ? split[1].retro.to!string : "";
        const file = split ? split[0].retro.to!string : value;

        suggestions.clear();

        // Make sure the directory exists
        if (!dir.exists || !dir.isDir) return;

        // Check the entries
        int num;
        foreach (entry; dir.dirEntries(file ~ "*", SpanMode.shallow)) {

            const name = entry.name.baseName;

            // Ignore hidden directories if not prompted
            if (!file.length && name.startsWith(".")) continue;

            // Stop after 10 entries.
            if (num++ >= 10) break;

            // Found a directory
            if (entry.isDir) suggestions ~= name ~ "/\n";

            // File
            else suggestions ~= name ~ "\n";

        }

        updateSize();

    }

    override void focus() {

        savedFocus = true;

        // Focus the input instead.
        tree.focus = input;

    }

    override bool isFocused() const {

        return input.isFocused();

    }

    protected override void drawImpl(Rectangle rect) {

        // Wasn't focused
        if (!savedFocus) {

            // Focus now
            focus();

            // Refresh suggestions
            updateSuggestions();

        }

        // Just lost focus
        else if (!isFocused) {

            cancel();
            return;

        }

        // If escape was pressed
        if (IsKeyPressed(KeyboardKey.KEY_ESCAPE)) {

            cancel();
            return;

        }

        super.drawImpl(rect);

    }

    protected override void resizeImpl(Vector2 space) {

        // Larger windows
        if (space.x > 600) {

            // Add margin
            input.size.x = space.x / 10 + 540;

        }

        else input.size.x = space.x;

        // Resize the node itself
        super.resizeImpl(space);

    }

}
