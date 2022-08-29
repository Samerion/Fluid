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

    mixin defineStyles!("selectedStyle", q{ Style.init });
    mixin enableInputActions;

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
        GluiFilenameInput input;

        /// Label with suggestions to the text.
        GluiRichLabel suggestions;

        /// Filename typed by the user, before choosing suggestions.
        string typedFilename;

        /// Currently chosen suggestion. 0 is no suggestion chosen.
        size_t currentSuggestion;

    }

    /// Create a file picker.
    ///
    /// Note: This is an "overlay" node, so it's expected to be placed in a global `onionFrame`. The constructor doesn't
    /// accept a layout parameter, as there is a default, constant one, required for the node to work correctly. This
    /// node is also hidden by default.
    this(const Theme theme, string name, void delegate() @trusted submitted,
        void delegate() @trusted cancelled = null)
    do {

        super(
            .layout(1, NodeAlign.center, NodeAlign.start),
            theme,

            titleLabel  = label(name),
            input       = new GluiFilenameInput("Path to file...", submitted),
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
            typedFilename = input.value;
            currentSuggestion = 0;
            updateSuggestions();

        };

        input.submitted = () {

            // Suggestion checked
            if (currentSuggestion != 0) {

                // Activate it
                typedFilename = input.value;
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

    inout(string) value() inout {

        return input.value;

    }

    string value(string newValue) {

        return typedFilename = input.value = newValue;

    }

    protected class GluiFilenameInput : GluiTextInput {

        mixin defineStyles;
        mixin enableInputActions;

        this(T...)(T args) {

            super(args);

        }

        @(GluiInputAction.entryUp)
        protected void _entryUp() {

            typedFilename = input.value = input.value.dirName;
            updateSuggestions();

        }

        @(GluiInputAction.cancel)
        protected void _cancel() {

            cancel();

        }

        @(GluiInputAction.entryPrevious)
        protected void _entryPrevious() {

            offsetSuggestion(-1);

        }

        @(GluiInputAction.entryNext)
        protected void _entryNext() {

            offsetSuggestion(+1);

        }

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

        return valueTuple(input.value);

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
    private void offsetSuggestion(long n) {

        const suggestionCount = (suggestions.textParts.length + 1);

        auto previous = currentSuggestion;
        currentSuggestion = (suggestionCount + currentSuggestion + n) % suggestionCount;

        // Clear style of the previous selection
        if (previous != 0 && previous < suggestionCount) {

            suggestions.textParts[previous - 1].style = null;

        }

        // Style thew new item
        if (currentSuggestion != 0) {

            auto part = &suggestions.textParts[currentSuggestion - 1];
            part.style = selectedStyle;

            input.value = valueTuple(typedFilename)[0] ~ part.text.stripLeft;

        }

        // Nothing selected
        else {

            // Restore original text
            input.value = typedFilename;

        }

    }

    override void focus() {

        savedFocus = true;

        // Focus the input instead.
        input.focus();

    }

    override bool isFocused() const {

        return input.isFocused();

    }

    protected override void drawImpl(Rectangle outer, Rectangle inner) @trusted {

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

        super.drawImpl(outer, inner);

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
