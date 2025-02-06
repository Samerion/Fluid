/// Basic implementation of clipboard I/O without communicating with the system. Exchanges clipboard data
/// only between nodes with access, and does not transfer them to other apps.
module fluid.clipboard_chain;

import fluid.node;
import fluid.types;
import fluid.utils;
import fluid.node_chain;

import fluid.io.clipboard;

@safe:

alias clipboardChain = nodeBuilder!ClipboardChain;

/// Local clipboard provider. Makes it possible to copy and paste text between nodes in the same branch.
///
/// `ClipboardChain` does not communicate with the system, so the clipboard will *not* be accessible to other apps.
/// This makes this node suitable for testing.
class ClipboardChain : NodeChain, ClipboardIO {

    private {
        string _value;
        typeof(controlIO!ClipboardIO()) _ioFrame;
    }

    this(Node next = null) {
        super(next);
    }

    /// Returns:
    ///     Current clipboard content.
    string value() const {
        return _value;
    }

    /// Replace the clipboard contents.
    /// Params:
    ///     newValue = New clipboard content.
    /// Returns:
    ///     Same text as passed into the function.
    string value(string newValue) {
        return _value = newValue;
    }

    override void beforeResize(Vector2) {
        _ioFrame = controlIO!ClipboardIO().startAndRelease();
    }

    override void afterResize(Vector2) {
        _ioFrame.stop();
    }

    override bool writeClipboard(string text) {
        _value = text;
        return true;
    }

    char[] readClipboard(return scope char[] buffer, ref int offset) nothrow {

        import std.algorithm : min;

        // Read the entire text, nothing remains to be read
        if (offset >= _value.length) return null;

        // Get remaining text
        const text = _value[offset .. $];
        const length = min(text.length, buffer.length);

        offset += length;
        return buffer[0 .. length] = text[0 .. length];

    }

}

///
@("Example of basic ClipboardChain usage compiles and works")
unittest {

    import fluid;

    TextInput first, second;

    // Children of a ClipboardChain will share the same clipboard
    auto root = clipboardChain(
        vspace(
            first  = textInput(),
            second = textInput(),
        ),
    );
    root.draw();

    // Text copied by the first input...
    first.value = "Hello!";
    first.selectAll();
    first.copy();

    // ... can now be pasted into the other
    second.paste();
    assert(second.value == "Hello!");

}
