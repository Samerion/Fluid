///
module fluid.hyperlink;

import fluid.label;
import fluid.utils;
import fluid.input;
import fluid.text.rope;

// This symbol should be moved into this module
public import fluid.utils : openURL;

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
