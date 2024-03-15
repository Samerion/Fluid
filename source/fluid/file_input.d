module fluid.file_input;

// To consider: Split into two modules, this plus generic text input with suggestions.

import std.conv;
import std.file;
import std.path;
import std.range;
import std.string;
import std.typecons;
import std.algorithm;

import fluid.text;
import fluid.space;
import fluid.label;
import fluid.utils;
import fluid.input;
import fluid.style;
import fluid.backend;
import fluid.button;
import fluid.structs;
import fluid.text_input;
import fluid.popup_frame;


@safe:


/// A file picker node.
///
/// Note, this node is hidden by default, use `show` or `spawnPopup` to display.
alias fileInput = simpleConstructor!FileInput;

/// ditto
class FileInput : PopupFrame {

    // TODO maybe create a generic "search all" component? Maybe something that could automatically collect all
    //      button data?

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
        Label titleLabel;

        /// Text input field containing the currently selected directory or file for the file picker.
        FilenameInput input;

        /// Space for all suggestions.
        ///
        /// Starts empty, and is filled in as suggestions appear. Buttons are reused, so no more buttons will be
        /// allocated once the suggestion limit is reached. Buttons are hidden if they don't contain any relevant
        /// suggestions.
        Space suggestions;

        /// Number of available suggestions.
        int suggestionCount;

        /// Filename typed by the user, before choosing suggestions.
        char[] typedFilename;

        /// Currently chosen suggestion. 0 is no suggestion chosen.
        size_t currentSuggestion;

    }

    /// Create a file picker.
    ///
    /// Note: This is an "overlay" node, so it's expected to be placed in a global `onionFrame`. The node assigns its
    /// own default layout, which typically shouldn't be overriden.
    this(string name, void delegate() @trusted submitted, void delegate() @trusted cancelled = null) {

        super(
            titleLabel  = label(name),
            input       = new FilenameInput("Path to file...", submitted),
            suggestions = vspace(.layout!"fill"),
        );

        this.layout = .layout(1, NodeAlign.center, NodeAlign.start);
        this.cancelled = cancelled;
        this.submitted = submitted;

        // Hide the node
        hide();

        // Windows is silly
        version (Windows) input.value = `C:\`.dup;
        else input.value = expandTilde("~/").dup;

        typedFilename = input.value;

        // Load suggestions
        addSuggestions();

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

    ref inout(Text!Label) text() inout {

        return titleLabel.text;

    }

    inout(char[]) value() inout {

        return input.value;

    }

    char[] value(char[] newValue) {

        updateSize();
        return typedFilename = input.value = newValue;

    }

    protected class FilenameInput : TextInput {

        mixin enableInputActions;

        this(T...)(T args) {

            super(args);

        }

        @(FluidInputAction.entryUp)
        protected void _entryUp() {

            typedFilename = input.value = input.value.dirName ~ "/";
            updateSuggestions();

        }

        @(FluidInputAction.cancel)
        protected void _cancel() {

            cancel();

        }

        @(FluidInputAction.entryPrevious)
        protected void _entryPrevious() {

            offsetSuggestion(-1);

        }

        @(FluidInputAction.entryNext)
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

        // TODO handle errors on a per-entry basis?
        try foreach (entry; dir.to!string.dirEntries(.text(file, "*"), SpanMode.shallow)) {

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

        catch (FileException exc) {

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
            suggestions.children ~= new FileInputSuggestion(this, index, text, {

                selectSuggestion(index + 1);
                reload();

            });

        }

        // Set text for the relevant button
        else {

            auto btn = cast(FileInputSuggestion) suggestions.children[index];

            btn.text = text;
            btn.show();

        }

    }

    /// Get the value as a (directory, file) tuple.
    private auto valueTuple() const {

        return valueTuple(input.value);

    }

    /// Ditto.
    private auto valueTuple(const(char)[] path) const {

        // Directory
        if (path.endsWith(dirSeparator)) {

            return tuple(path, (const(char)[]).init);

        }

        const file = path.baseName;
        return tuple(
            path.chomp(file),
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
    private void selectSuggestion(size_t n) {

        auto previous = currentSuggestion;
        currentSuggestion = n;

        updateSize();

        // Update input to match suggestion
        if (currentSuggestion != 0) {

            auto btn = cast(FileInputSuggestion) suggestions.children[currentSuggestion - 1];
            auto newValue = to!(char[])(valueTuple(typedFilename)[0] ~ btn.text.value.stripLeft);

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
    private void offsetSuggestion(size_t n) {

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
            || cast(const FileInputSuggestion) tree.focus;

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

        assert(false, "FileInput cannot directly have focus; call FluidFilePicker.focus to resolve automatically");

    }

}

/// Suggestion button for styling.
class FileInputSuggestion : Button {

    mixin enableInputActions;

    private {

        int _index;
        FileInput _input;

    }

    private this(FileInput input, int index, string text, void delegate() @safe callback) {

        super(text, callback);
        this.layout = .layout!"fill";
        this._index = index;
        this._input = input;

    }

    /// File input the button belongs to.
    inout(FileInput) parent() inout => _input;

    /// Index of the button.
    int index() const => _index;

    /// True if this suggestion is selected.
    bool isSelected() const => _input.currentSuggestion == _index+1;

}
