/// This module exists to test the `moduleView` component. Content is extracted from documentation comments.
/// Paragraphs can span multiple lines and are separated by a blank line. Leading and trailing whitespace is ignored.
///
/// Declarations marked with a documentation comment should be included in the result as a code sample. Furthermore,
/// documented unittests should be evaluated, with nodes passed to `run()` and `stdout` & `stderr` output visible to
/// the side.
module fluid.tour.module_view;

import fluid;

@safe:

/// To present, here's an unittest that outputs a node:
unittest {

    run(
        label("Hello, World!")
    );

}
