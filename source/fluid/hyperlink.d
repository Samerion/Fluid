///
module fluid.hyperlink;

import fluid.node;
import fluid.label;
import fluid.text.rope;
import fluid.input_node;

@safe:

/// Basic builder for the `Hyperlink` node.
alias hyperlink = nodeBuilder!Hyperlink;

/// A hyperlink is a reference in text that opens a document or a web page when clicked.
///
/// This is the equivalent of [the HTML `<a>` element](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/a).
class Hyperlink : InputNode!Label {

    mixin enableInputActions;

    public {

        /// URL address this hyperlink connects to.
        ///
        /// Clicking the link will open this page in a relevant app (web browser).
        string url;

    }

    /// Create a hyperlink.
    /// Params:
    ///     url  = URL this link points to.
    ///     text = Visible text describing this link. 
    ///         If not specified, the URL will be used.
    this(string url, Rope text) {

        super(text);
        this.url = url;

    }

    /// ditto
    this(string url, string text) {

        super(text);
        this.url = url;

    }

    /// ditto
    this(string url) {

        this(url, url);

    }

    /// Open this link in an external application.
    @(FluidInputAction.press)
    void press() {

        openURL(url);

    }

}

/// Open given URL in a web browser.
///
/// Supports all major desktop operating systems. Does nothing if not supported on the given platform.
///
/// At the moment this simply wraps `std.process.browse`.
void openURL(scope const(char)[] url) nothrow {

    version (Posix) {
        import std.process;
        browse(url);
    }
    else version (Windows) {
        import std.process;
        browse(url);
    }

    // Do nothing on remaining platforms

}
