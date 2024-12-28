/// Module defining interfaces for connecting to and handling [clipboard].
///
/// The clipboard is a buffer that allows copying and moving text between nodes, or between apps in the system.
///
/// [clipboard]: https://en.wikipedia.org/wiki/Clipboard_(computing)
module fluid.io.clipboard;

import fluid.future.context;

@safe:

/// Interface for writing and loading text to the clipboard.
///
/// The [clipboard] is a buffer that allows copying and moving text between nodes, or between apps in the system.
interface ClipboardIO : IO {

    /// Write text to the clipboard.
    /// Params:
    ///     text = Text to store in the clipboard.
    /// Returns:
    ///     True if data was written, including if given text was empty.
    bool writeClipboard(string text) nothrow;

    /// Read text from the clipboard.
    ///
    /// This function works in the same way as `FocusIO.readText`:
    /// All the text will be written by reference into the provided buffer, overwriting previously stored text.
    /// The returned value will be a slice of this buffer, representing the entire value.
    /// The buffer may not fit the entire text. Because of this, the function should be called repeatedly until the
    /// returned value is `null`.
    ///
    /// This function may not throw: In the instance the offset extends beyond text boundaries, the buffer is empty
    /// or text cannot be read, this function should return `null`, as if no text should remain to read.
    ///
    /// Params:
    ///     buffer = Buffer to write clipboard text into.
    ///     offset = Index of the system clipboard to start writing from.
    /// Returns:
    ///     A slice of the buffer containing clipboard data, or `null` if no data remains to be written.
    char[] readClipboard(return scope char[] buffer, ref int offset) nothrow
    out(text; text is buffer[0 .. text.length] || text is null,
        "Returned value must be a slice of the buffer, or be null")
    out(text; text is null || text.length > 0,
        "Returned value must be null if it is empty");

}
