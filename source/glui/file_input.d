module glui.file_input;

// To consider: Split into two modules, this plus generic text input with suggestions.

import raylib;
import std.conv;
import std.file;
import std.path;
import std.range;
import std.string;
import std.typecons;
import std.algorithm;

import glui.space;
import glui.frame;
import glui.label;
import glui.utils;
import glui.input;
import glui.style;
import glui.button;
import glui.structs;
import glui.text_input;

alias fileInput = simpleConstructor!GluiFileInput;

deprecated("filePicker has been renamed to fileInput. Please update references before 0.7.0.")
alias filePicker = fileInput;

deprecated("GluiFilePicker has been renamed to GluiFileInput. Please update references before 0.7.0.")
alias GluiFilePicker = GluiFileInput;

@safe:

/// A file picker node.
///
/// Note, this node is hidden by default, use `show` to show.
/// Styles: $(UL
///     $(LI `selectedStyle` = Style for the currently selected suggestion.)
/// )
class GluiFileInput : GluiInput!GluiFrame {

    // TODO maybe create a generic "search all" component? Maybe something that could automatically collect all
    //      button data?

    mixin defineStyles!(
        "unselectedStyle", q{ Style.init },
        "selectedStyle", q{ unselectedStyle },
        "suggestionHoverStyle", q{ selectedStyle },
    );
    mixin enableInputActions;

    /// Callback to run when input was cancelled.
    void delegate() cancelled;

    /// Callback to run when input was submitted.
    void delegate() submitted;

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

        /// Space for all suggestions.
        ///
        /// Starts empty, and is filled in as suggestions appear. Buttons are reused, so no more buttons will be
        /// allocated once the suggestion limit is reached. Buttons are hidden if they don't contain any relevant
        /// suggestions.
        GluiSpace suggestions;

        /// Number of available suggestions.
        int suggestionCount;

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
            NodeParams(
                .layout(1, NodeAlign.center, NodeAlign.start),
                theme,
            ),

            titleLabel  = label(name),
            input       = new GluiFilenameInput(NodeParams.init, "Path to file...", submitted),
            suggestions = vspace(.layout!"fill"),
        );

        this.cancelled = cancelled;
        this.submitted = submitted;

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

                reload();

                // Restore focus
                focus();

            }

            // Final submit
            else submit();

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

        updateSize();
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

            typedFilename = input.value = input.value.dirName ~ "/";
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

    /// Clear suggestions
    void clearSuggestions() {

        updateSize();
        suggestionCount = 0;

        // Hide all suggestion children
        foreach (child; suggestions.children) {

            child.hide();

        }

    }

    /// Refresh the suggestion list.
    void updateSuggestions() {

        const values = valueTuple;
        const dir  = values[0];
        const file = values[1];

        clearSuggestions();

        // Make sure the directory exists
        if (!dir.exists || !dir.isDir) return;

        // Check the entries
        addSuggestions();

        // Current suggestion was removed
        if (currentSuggestion > suggestionCount) {

            currentSuggestion = suggestionCount;

        }

    }

    private void submit() {

        // Submit the selection
        if (submitted) submitted();

        // Remove focus
        super.isFocused = false;
        savedFocus = false;
        hide();

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

            // Stop after reaching the limit
            if (num++ >= suggestionLimit) break;


            // Found a directory
            if (entry.isDir) pushSuggestion(name ~ "/");

            // File
            else pushSuggestion(name);

        }

    }

    private void pushSuggestion(string text) {

        const index = suggestionCount;

        // Ignore if the suggestion limit was reached
        if (suggestionCount >= suggestionLimit) return;

        updateSize();
        suggestionCount += 1;

        // Check if the suggestion button has been allocated
        if (index >= suggestions.children.length) {

            // Create the button
            suggestions.children ~= new SuggestionButton(this, index, text, {

                selectSuggestion(index + 1);
                reload();

            });

        }

        // Set text for the relevant button
        else {

            auto btn = cast(SuggestionButton) suggestions.children[index];

            btn.text = text;
            btn.show();

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

    // TODO perhaps some of these should be exposed as API.

    /// Reload the suggestions using user input.
    private void reload() {

        typedFilename = input.value;
        currentSuggestion = 0;
        updateSuggestions();

    }

    /// Set current suggestion by number.
    private void selectSuggestion(long n) {

        auto previous = currentSuggestion;
        currentSuggestion = n;

        updateSize();

        // Update input to match suggestion
        if (currentSuggestion != 0) {

            auto btn = cast(SuggestionButton) suggestions.children[currentSuggestion - 1];
            auto newValue = valueTuple(typedFilename)[0] ~ btn.text.stripLeft;

            // Same value, submit
            if (newValue == input.value) submit();

            // Update the input
            else input.value = newValue;

        }

        // Nothing selected
        else {

            // Restore original text
            input.value = typedFilename;

        }

    }

    /// Offset currently chosen selection by number.
    private void offsetSuggestion(long n) {

        const indexLimit = suggestionCount + 1;

        selectSuggestion((indexLimit + currentSuggestion + n) % indexLimit);

    }

    override void focus() {

        savedFocus = true;

        // Focus the input instead.
        input.focus();

    }

    override bool isFocused() const {

        return input.isFocused()
            || cast(const SuggestionButton) tree.focus;

    }

    protected override void drawImpl(Rectangle outer, Rectangle inner) @trusted {

        super.drawImpl(outer, inner);

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

        assert(false, "GluiFileInput cannot directly have focus; call GluiFilePicker.focus to resolve automatically");

    }

}

private class SuggestionButton : GluiButton!() {

    mixin enableInputActions;

    private {

        int index;
        GluiFileInput input;

    }

    this(T...)(GluiFileInput input, int index, T args) {

        super(NodeParams(.layout!"fill"), args);
        this.index = index;
        this.input = input;

    }

    override const(Style) pickStyle() const {

        // Selected
        if (input.currentSuggestion == index+1)
            return input.selectedStyle;

        // Hovered
        if (isHovered)
            return input.suggestionHoverStyle;

        // Idle
        return input.unselectedStyle;

    }

}
