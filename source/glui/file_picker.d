///
module glui.file_picker;

// To consider: Split into two modules, this plus generic text input with suggestions.

import raylib;
import std.conv;
import std.file;
import std.path;
import std.range;
import std.string;
import std.typecons;
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

@safe:

/// A file picker node.
///
/// Note, this node is hidden by default, use `show` to show.
/// Styles: $(UL
///     $(LI `selectedStyle` = Style for the currently selected suggestion.)
/// )
class GluiFilePicker : GluiInput!GluiFrame {

    mixin DefineStyles!("selectedStyle", q{ Style.init });

    /// Callback to run when input was cancelled.
    void delegate() cancelled;

    /// Max amount of suggestions that can be provided.
    size_t suggestionLimit = 10;

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

        /// Filename typed by the user, before choosing suggestions.
        string typedFilename;

        /// Currently chosen suggestion. 0 is no suggestion chosen.
        size_t currentSuggestion;

    }

    this(const Theme theme, string name, void delegate() @trusted submitted,
        void delegate() @trusted cancelled = null)
    do {

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

        typedFilename = input.value;

        // Bind events
        input.changed = () {

            // Trigger an event
            if (changed) changed();

            // Update suggestions
            typedFilename = value;
            currentSuggestion = 0;
            updateSuggestions();

        };

        input.submitted = () {

            // Suggestion checked
            if (currentSuggestion != 0) {

                // Activate it
                typedFilename = value;
                currentSuggestion = 0;
                updateSuggestions();

                // Restore focus
                focus();

            }

            // Final submit
            else {

                // Submit the selection
                if (submitted) submitted();

                // Remove focus
                super.isFocused = false;
                savedFocus = false;

                // Automatically hide when submitted
                hide();

            }
        };

    }

    this(string name, void delegate() @trusted submitted, void delegate() @trusted cancelled = null) {

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

        const values = valueTuple;
        const dir  = values[0];
        const file = values[1];

        suggestions.clear();

        // Make sure the directory exists
        if (!dir.exists || !dir.isDir) return;

        // Check the entries
        addSuggestions();

        // This suggestion was removed
        if (currentSuggestion > suggestions.textParts.length) {

            currentSuggestion = suggestions.textParts.length;

        }

        updateSize();

    }

    private void addSuggestions() @trusted {

        const values = valueTuple;
        const dir  = values[0];
        const file = values[1];

        ulong num;
        foreach (entry; dir.dirEntries(file ~ "*", SpanMode.shallow)) {

            const name = entry.name.baseName;

            // Ignore hidden directories if not prompted
            if (!file.length && name.startsWith(".")) continue;

            // Stop after 10 entries.
            if (num++ >= 10) break;


            const prefix = num > 1 ? "\n" : "";

            // Get the style
            auto style = currentSuggestion == num
                ? selectedStyle
                : null;

            // Found a directory
            if (entry.isDir) suggestions.push(style, prefix ~ name ~ "/");

            // File
            else suggestions.push(style, prefix ~ name);

        }

    }

    /// Get the value as a (directory, file) tuple.
    private auto valueTuple() const {

        return valueTuple(value);

    }

    /// Ditto.
    private auto valueTuple(string path) const {

        // Directory
        if (path.endsWith(dirSeparator)) {

            return tuple(path, "");

        }

        const file = path.baseName;
        return tuple(
            path.chomp(file).to!string,
            file,
        );

    }

    /// Offset currently chosen selection by number.
    private void offsetSuggestion(ulong n) {

        auto previous = currentSuggestion;
        currentSuggestion = (currentSuggestion + n) % (suggestions.textParts.length + 1);

        // Clear style of the previous selection
        if (previous != 0 && previous <= suggestions.textParts.length) {

            suggestions.textParts[previous - 1].style = null;

        }

        // Style thew new item
        if (currentSuggestion != 0) {

            auto part = &suggestions.textParts[currentSuggestion - 1];
            part.style = selectedStyle;

            value = valueTuple(typedFilename)[0] ~ part.text.stripLeft;

        }

        // Nothing selected
        else {

            // Restore original text
            value = typedFilename;

        }

    }

    override void focus() {

        savedFocus = true;

        // Focus the input instead.
        tree.focus = input;

    }

    override bool isFocused() const {

        return input.isFocused();

    }

    protected override void drawImpl(Rectangle rect) @trusted {

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


        with (KeyboardKey) {

            // If escape was pressed
            if (IsKeyPressed(KEY_ESCAPE)) {

                cancel();
                return;

            }

            // Ctrl
            else if (IsKeyDown(KEY_LEFT_CONTROL)) {

                // Vim
                if (IsKeyPressed(KEY_K)) offsetSuggestion(-1);
                else if (IsKeyPressed(KEY_J)) offsetSuggestion(1);

                // Emacs
                if (IsKeyPressed(KEY_P)) offsetSuggestion(-1);
                else if (IsKeyPressed(KEY_N)) offsetSuggestion(1);

            }

            // Alt
            else if (IsKeyDown(KEY_LEFT_ALT)) {

                // Dir up
                if (IsKeyPressed(KEY_UP)) {

                    typedFilename = value = value.dirName;
                    updateSuggestions();

                }

            }

            // Go up
            else if (IsKeyPressed(KEY_UP)) offsetSuggestion(-1);

            // Go down
            else if (IsKeyPressed(KEY_DOWN)) offsetSuggestion(1);

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

    protected override void mouseImpl() {

        input.focus();

    }

    // Does nothing
    protected override bool keyboardImpl() {

        assert(false, "FilePicker cannot directly have focus; call filePicker.focus to resolve automatically");

    }

}
